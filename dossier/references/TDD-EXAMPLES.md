# TDD examples

Load only when canonical `TDD-ROUND.md` is too abstract.

## True RED — three stacks

### Web frontend (Playwright + behavioural spec)

```
RED:
  Write apps/docs/tests/behavioural/header-active-link.behaviour.spec.ts
    (asserts active link's computed border-bottom-color
     = rgb(255, 191, 0), font-weight = 700)
  long_command: pnpm exec playwright test --project=behavioural-desktop \
                       -g 'header-active-link' --reporter=line
  resume_after_wait(90s or runtime equivalent)
  → FAIL: "Expected: rgb(255, 191, 0)  Received: rgba(0, 0, 0, 0)"

GREEN:
  Edit apps/docs/src/styles/showcase.css:
    .site-header__nav a[aria-current='page'] {
      border-bottom-color: var(--yellow-gold);
      font-weight: 700;
    }
  long_command: pnpm build
  resume_after_wait(120s or runtime equivalent)
  run_command: pnpm exec playwright test (narrow)  → PASS

Adjacent check + rebaseline:
  long_command: pnpm exec playwright test --update-snapshots
  → 15 PNGs updated.

Land:
  git add src/styles/showcase.css \
          tests/behavioural/header-active-link.behaviour.spec.ts \
          tests/visual/__snapshots__/{handbook,routes}.spec.ts
  git commit -m "feat(docs): paint yellow-gold underline on active nav link"
```

### Backend API (Go test + golden HTTP response)

```
RED:
  Write internal/orders/idempotency_test.go
    (asserts: POST /v2/orders with same Idempotency-Key returns 200 + same body,
     not 409, on retry)
  run_command: go test ./internal/orders/ -run TestIdempotentRetry -count=1
  → FAIL: "expected status 200, got 409"

GREEN:
  Edit internal/orders/handler.go:
    + record key in idempotency_store on first success
    + on duplicate key, replay stored response (200), don't re-execute
  run_command: go test ./internal/orders/ -run TestIdempotentRetry -count=1
  → PASS

Adjacent check + contract freeze:
  run_command: go test ./... -count=1
  run_command: make openapi    (re-emits openapi.v2.yaml)
  run_command: git diff --stat openapi.v2.yaml   → 0 lines (no surface change)

Land:
  git add internal/orders/handler.go \
          internal/orders/idempotency_test.go
  git commit -m "fix(api): replay stored response on idempotency key reuse"
```

### CLI tool (bats + golden stdout)

```
RED:
  Write tests/golden/init-dry-run.bats
    @test "tool init --dry-run prints plan to stdout, exits 0" {
      run tool init --dry-run
      [ "$status" -eq 0 ]
      diff <(echo "$output") tests/golden/init-dry-run.txt
    }
  run_command: bats tests/golden/init-dry-run.bats
  → FAIL: "exit status 1, expected 0" + golden missing

GREEN:
  Edit cmd/init.go:
    + handle --dry-run: print plan, exit 0 without mutating fs
  run_command: BATS_UPDATE_GOLDEN=1 bats tests/golden/init-dry-run.bats
  Read tests/golden/init-dry-run.txt   (verify content matches intent)
  run_command: bats tests/golden/init-dry-run.bats   → PASS

Land:
  git add cmd/init.go \
          tests/golden/init-dry-run.bats \
          tests/golden/init-dry-run.txt
  git commit -m "feat(cli): add --dry-run to init, print plan no-mutate"
```

## Coverage-only example — meta-gate sibling

When impl edit = config/threshold/structural file (no obvious
component-test sibling), **meta-test** = sibling. See `META-GATE.md`.

```
RED:
  Write packages/uikit/src/_meta/coverage-thresholds.test.ts
    (reads vitest.config, asserts thresholds >= floor)
  run_command: pnpm exec vitest run src/_meta/coverage-thresholds
  → FAIL: "statements threshold 70 must be >= 85"

GREEN:
  Edit packages/uikit/vitest.config.ts:
    thresholds: { statements: 85, branches: 80, functions: 85, lines: 85 }
  → TDD gate/adapter accepts (meta-test is the sibling in git diff)
  run_command: pnpm exec vitest run src/_meta/coverage-thresholds
  → PASS

Land:
  Single commit covering both files.
```
