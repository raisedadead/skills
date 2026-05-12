# Commit examples — phase tails across stacks

Deferred reference. Load only when the abstract rules in `COVENANT.md` need concrete shape. Each block below is one phase's commit tail across a different stack. Every commit bundles its sibling test + impl; subject ≤ 50 chars; no body; no emoji; no phase / bug tag in the message — `SPEC.md §B` is the canonical ledger.

## Web frontend phase tail (PNG rebaseline + tokens)

```
b15e4a6 fix(docs): lock preview spans full card chrome
09c1657 fix(docs): explicit type=button on .showcase__tab
b4e718f fix(docs): swap hex literals in showcase.css for tokens
c90490f test(docs): lock tooltip + data-table behavioural contracts
```

## Backend service phase tail (OpenAPI freeze + migration)

```
9a1c33d feat(api): add idempotency_key to POST /v2/orders
3b71a04 fix(db): linear migration 0042 — add tier column, default free
e217c50 fix(db): migration 0042 idempotent on rerun
```

## CLI tool phase tail (golden stdout + exit codes)

```
2c4d1f6 fix(cli): exit 64 on usage error not 1
8e91207 feat(cli): golden stdout for `tool init --dry-run`
4f01a8a refactor(cli): split flag parser, add no-color sentinel
```

## Library phase tail (public API surface + semver)

```
9f1e2c8 feat(core): rename `compute()` → `evaluate()` — breaking
3a72f1d fix(auth): null-safe token refresh
```

## Pattern

Across all four: each subject ≤ 50 chars, names the surface (`scope`), states the outcome. No bodies. No emoji. No phase tag. Sibling test always in the same commit's diff. Phase closeout written under `.scratchpad/dossier/closeout/`, **not** committed as a package-manager changeset.
