# TDD round — RED → GREEN → COMMIT

Canonical sequence executed for every task in a phase. Two
flavours:

- **True RED-then-GREEN** — behaviour is wrong; test fails first, impl fix turns it green.
- **Coverage-only round** — behaviour is correct; test exists to lock coverage / contract. Tests pass on first run.

Both follow the same shape, regardless of stack.

## Sequence (stack-neutral)

```
TaskUpdate({ taskId, status: "in_progress" })

# Read context
Read <impl file>
Read <existing test file (if any)>
Read <audit section>            # .dossier/AUDIT.md offset+limit

# RED
Write <new sibling test file>   # asserts the rule the impl change will encode
Bash: <narrow test run>         # confirm RED (or coverage-only PASS)

# GREEN
Edit <impl file>                # PreToolUse TDD gate now accepts (sibling in git diff)
Bash: <narrow test run>         # confirm GREEN

# Adjacent check
Bash: <full test run + coverage / contract diff>
                                # confirm no regression elsewhere

# Land (rebaseline goldens included if output changed)
Bash: git add <explicit paths>
Bash: git commit -m "type(scope): subject (P<N>-Bxx)"

TaskUpdate({ taskId, status: "completed" })
```

## True RED — three worked examples across stacks

### Web frontend (Playwright + behavioural spec)

```
RED:
  Write apps/docs/tests/behavioural/header-active-link.behaviour.spec.ts
    (asserts active link's computed border-bottom-color
     = rgb(255, 191, 0), font-weight = 700)
  Bash (background): pnpm exec playwright test --project=behavioural-desktop \
                       -g 'header-active-link' --reporter=line
  ScheduleWakeup(90s)
  → FAIL: "Expected: rgb(255, 191, 0)  Received: rgba(0, 0, 0, 0)"

GREEN:
  Edit apps/docs/src/styles/showcase.css:
    .site-header__nav a[aria-current='page'] {
      border-bottom-color: var(--yellow-gold);
      font-weight: 700;
    }
  Bash (background): pnpm build
  ScheduleWakeup(120s)
  Bash: pnpm exec playwright test (narrow)  → PASS

Adjacent check + rebaseline:
  Bash (background): pnpm exec playwright test --update-snapshots
  → 15 PNGs updated.

Land:
  git add src/styles/showcase.css \
          tests/behavioural/header-active-link.behaviour.spec.ts \
          tests/visual/__snapshots__/{handbook,routes}.spec.ts
  git commit -m "feat(docs): paint yellow-gold underline on active nav link (P9-B8)"
```

### Backend API (Go test + golden HTTP response)

```
RED:
  Write internal/orders/idempotency_test.go
    (asserts: POST /v2/orders with same Idempotency-Key returns 200 + same body,
     not 409, on retry)
  Bash: go test ./internal/orders/ -run TestIdempotentRetry -count=1
  → FAIL: "expected status 200, got 409"

GREEN:
  Edit internal/orders/handler.go:
    + record key in idempotency_store on first success
    + on duplicate key, replay stored response (200), don't re-execute
  Bash: go test ./internal/orders/ -run TestIdempotentRetry -count=1
  → PASS

Adjacent check + contract freeze:
  Bash: go test ./... -count=1
  Bash: make openapi    (re-emits openapi.v2.yaml)
  Bash: git diff --stat openapi.v2.yaml   → 0 lines (no surface change)

Land:
  git add internal/orders/handler.go \
          internal/orders/idempotency_test.go
  git commit -m "fix(api): replay stored response on idempotency key reuse (P3-B7)"
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
  Bash: bats tests/golden/init-dry-run.bats
  → FAIL: "exit status 1, expected 0" + golden missing

GREEN:
  Edit cmd/init.go:
    + handle --dry-run: print plan, exit 0 without mutating fs
  Bash: BATS_UPDATE_GOLDEN=1 bats tests/golden/init-dry-run.bats
  Read tests/golden/init-dry-run.txt   (verify content matches intent)
  Bash: bats tests/golden/init-dry-run.bats   → PASS

Land:
  git add cmd/init.go \
          tests/golden/init-dry-run.bats \
          tests/golden/init-dry-run.txt
  git commit -m "feat(cli): add --dry-run to init, print plan no-mutate (P2-B2)"
```

## Coverage-only example — meta-gate sibling

When the impl edit is a config / threshold / structural file
(no obvious component-test sibling), a **meta-test** is the
sibling. See `META-GATE.md`.

```
RED:
  Write packages/uikit/src/_meta/coverage-thresholds.test.ts
    (reads vitest.config, asserts thresholds >= floor)
  Bash: pnpm exec vitest run src/_meta/coverage-thresholds
  → FAIL: "statements threshold 70 must be >= 85"

GREEN:
  Edit packages/uikit/vitest.config.ts:
    thresholds: { statements: 85, branches: 80, functions: 85, lines: 85 }
  → PreToolUse gate accepts (meta-test is the sibling in git diff)
  Bash: pnpm exec vitest run src/_meta/coverage-thresholds
  → PASS

Land:
  Single commit covering both files.
```

## Total wall clock

A typical coverage-only round runs ~3 minutes. A true RED →
GREEN → rebaseline round runs ~10–15 minutes (one or two
ScheduleWakeup cycles for the build + rebaseline).

## Stack runner cheat-sheet (narrow runs)

| Stack         | Narrow test command                                                   |
| ------------- | --------------------------------------------------------------------- |
| Node + vitest | `pnpm exec vitest run <pattern> --reporter=basic`                     |
| Node + jest   | `pnpm exec jest <pattern> --runInBand`                                |
| Playwright    | `pnpm exec playwright test --project=<p> -g '<name>' --reporter=line` |
| Go            | `go test ./<pkg>/ -run <Test> -count=1`                               |
| Python        | `pytest -k '<expr>' -x`                                               |
| Rust          | `cargo test <name> --no-fail-fast`                                    |
| Java (maven)  | `mvn -Dtest=<Class>#<method> test`                                    |
| Bash (bats)   | `bats tests/<file>.bats`                                              |
| Terraform     | `terraform test -filter=<file>`                                       |
| dbt           | `dbt test --select <model>+ --fail-fast`                              |
