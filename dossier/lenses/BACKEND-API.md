# Lens — Backend API

For HTTP / RPC services — REST/GraphQL/gRPC, with OpenAPI or
proto contracts, DB migrations, and idempotency / retry concerns.

## Surface vocabulary

- **Unit:** route / RPC method / queue handler (`POST /v2/orders`, `OrdersService.Create`).
- **Output:** OpenAPI / proto spec, JSON response shape, status code, header set, log line, emitted event.
- **Contract:** OpenAPI `.yaml` / `.proto` / GraphQL schema + status-code matrix + idempotency key + auth scope.

## Gate menu (select per phase)

These are gate candidates, not defaults. Copy only selected gates into
`PLAN.md` / `SPEC.md`; leave the rest as context.

- **OpenAPI freeze.** `openapi.v2.yaml` is committed; CI runs `make openapi && git diff --exit-code`. Diff → fail. Update both in same commit.
- **Migration linearity.** Filenames in `db/migrations/` strictly monotonic; no two migrations claim the same number.
- **Reversible migrations.** Every `up.sql` has `down.sql`; meta-gate parses both, asserts `down` reverses `up` for additive cases.
- **Status-code matrix.** Per route: which 2xx, 4xx, 5xx are documented? Meta-gate cross-references handler returns vs OpenAPI `responses` keys.
- **Idempotency key on every state-mutating route.** Walk routes, regex offenders missing `Idempotency-Key` header / spec.
- **Auth scope on every route.** Every route declares a scope; meta-gate rejects routes without `security:` block.
- **Env-var contract.** `.env.example` lists every var read by the code; no drift.

## Output rebaseline specifics

| Step              | Command                                             |
| ----------------- | --------------------------------------------------- |
| Regenerate        | `make openapi` / `buf generate` / `prisma generate` |
| Unbaselined diff  | `git diff openapi.v2.yaml` / `git diff proto/`      |
| Read failures     | route added/removed/changed listed in diff          |
| Accept            | stage the regenerated artefact                      |
| Contract test run | `pnpm test:contract` / `go test ./test/contract/`   |

Goldens: `openapi.v2.yaml`, `proto/*.proto`, `tests/contract/__snapshots__/`.

## Probe specifics

- File: `_probe-<slug>_test.go` / `tests/test_probe_<slug>.py` / `tests/contract/_probe-<slug>.spec.ts`
- Runner: `go test ./<pkg>/ -run _probe -v -count=1` / `pytest -k _probe_<slug> -s`
- Dump shape: `t.Logf` / `print` of: request body, response status + body, DB row count + checksum, store keys, header dump, retry count.
- Common dump targets: idempotency-store contents, query plan (`EXPLAIN ANALYZE`), connection-pool stats, retry-after headers.

## Stack footguns

- **Migration applied non-atomically across replicas.** → use online schema change (`pt-online-schema-change`, `gh-ost`); never `ALTER TABLE` on hot tables.
- **`SELECT *` in handler vs `SELECT id, …` in test fixture.** Drift on schema add. → pin column list in handler; meta-gate on offenders.
- **Idempotency store leak.** Keys never expire → grow forever. → set TTL; meta-gate on store config.
- **Retry storm on 5xx.** Client retries before circuit-breaker kicks in. → exponential backoff + jitter; assert in contract test.
- **Race on optimistic locking.** Two writers, neither sees the other's `version`. → assert via concurrent-write test.
- **Auth bypass via missing scope on new route.** → meta-gate on `security:` block.
- **Time-zone drift.** Tests pass in UTC, fail in deploy zone. → `TZ=UTC` in test env; meta-gate on `time.Now()` calls (use injected clock).
- **`SELECT … FOR UPDATE` outside transaction.** Lock released immediately. → integration test with two connections.
- **Pagination on unsorted query.** Page 2 overlaps page 1. → meta-gate on `LIMIT` without `ORDER BY`.

## Phase shape hint (optional)

Typical sub-phases for a backend-API phase:

- P0 — OpenAPI / proto baseline freeze
- P1 — contract-test scaffold + meta-gates (status matrix, scope, idempotency)
- P2 — migration linearity + reversibility gate
- P3 — feature work (per-route TDD rounds)
- P4 — perf / load gate (p99 floor)
- P5 — observability — logs / traces / metrics on new routes
- P6 — release / cut + closeout
