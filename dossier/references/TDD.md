# TDD — RED → GREEN → COMMIT

Canonical sequence per task in a phase. Two flavours:

- **True RED-then-GREEN** — behaviour wrong; test fails first, impl fix turns it green.
- **Coverage-only round** — behaviour correct; the test locks the coverage / contract. Test passes first run.

Both follow the same shape on any stack.

## Test quality rules

- Test behaviour via public interfaces, not impl details.
- One vertical tracer bullet at a time: one behaviour → one test → one impl step.
- No "write all tests first, then all impl". Horizontal slice = brittle imagined tests.
- Prefer integration-style tests; they survive internal refactors.
- Mock only true external boundaries. No mocking internal collaborators just to assert call counts.
- Test names + task subjects use project vocabulary from `CONTEXT.md` / ADRs when those docs exist.

## Sequence (stack-neutral)

```
task_start

# Read context
Read <impl file>
Read <existing test file (if any)>
Read <SPEC.md §T/§V/§I rows>
Read <audit finding>            # .scratchpad/dossier/AUDIT.md row/detail

# RED
Write <new sibling test file>   # one behaviour through public interface
run_command: <narrow test run>  # confirm RED (or coverage-only PASS)

# RED diagnosis — failure must be on the assertion you care about.
# These are BROKEN TESTS, not RED:
#   - ImportError / ModuleNotFoundError / SyntaxError
#   - "fixture not found" / "test not collected" / 0 tests run
#   - NameError / undefined symbol in the test itself
#   - timeout before assertion / setup-only crash
# If failure looks like any of those, fix the test until it fails for
# the *behaviour reason* (assertion mismatch, exception from impl).
# Then proceed to GREEN.

# GREEN
Edit <impl file>                # TDD gate/adapter accepts (sibling in git diff)
run_command: <narrow test run>  # confirm GREEN

# Adjacent check
run_command: <full test run + coverage / contract diff>
                                # confirm no regression elsewhere

# Land (rebaseline goldens included if output changed)
commit_paths: <explicit paths>, "type(scope): subject"

task_done
```

If verification fails, do not retry blind. Use `BACKPROP.md` to decide: code bug, spec bug, or missing invariant. Resume the round with updated evidence.

## Total wall clock

Typical coverage-only round ~3 min. True RED → GREEN → rebaseline round ~10–15 min (one or two runtime wait/resume cycles for build + rebaseline).

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

______________________________________________________________________

## Examples (deferred)

Load this section only when the abstract sequence above is not enough. Three true-RED examples across stacks plus one coverage-only / meta-gate example.

### True RED — web frontend (Playwright + behavioural spec)

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

### True RED — backend API (Go test + golden HTTP response)

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

### True RED — CLI tool (bats + golden stdout)

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

### Coverage-only — meta-gate sibling

When the impl edit is a config / threshold / structural file (no obvious component-test sibling), a **meta-test** is the sibling. See `META-GATE.md`.

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

______________________________________________________________________

## TDD gate hook (optional)

Sibling-test enforcement can be wired as a `PreToolUse` hook so an impl edit without a same-worktree test / meta-gate / golden / contract / schema / recorded-output sibling is blocked.

Script: `scripts/tdd-gate.py`. Python 3 stdlib only. Standalone — no kernel-side or personal-config dependencies.

### Fires when

All three must hold:

- `.scratchpad/dossier/SPEC.md` exists (dossier is active).
- Target path looks like source / config / contract.
- Current worktree shows no test, meta-gate, golden, contract, schema, or recorded-output evidence.

### Behavior

Exit `0`: allow edit. Exit `2`: block edit and feed stderr to the runtime.

Block message tells the operator:

1. Write / update the failing behaviour test first.
1. Run the narrow test, confirm RED.
1. Re-attempt the impl edit.
1. For config / contract / output changes, add a meta-gate or recorded-output sibling.

### Claude Code wiring

Project-local `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 <skill-dir>/scripts/tdd-gate.py"
          }
        ]
      }
    ]
  }
}
```

Replace `<skill-dir>` with the installed dossier skill path. If dossier is vendored into the repo, use a project-relative path. Co-installs cleanly with `marker-guard.py` and `commit-guard.py` — all three can share the matcher list on edit-class tools, and the Bash matcher for commit-guard.

### OpenCode wiring

OpenCode exposes `PreToolCall` with a near-identical payload:

```jsonc
{
  "hooks": {
    "PreToolCall": [
      {
        "match": { "tool": "Edit" },
        "command": ["python3", "<skill-dir>/scripts/tdd-gate.py"]
      }
    ]
  }
}
```

### Codex / generic runtime

For runtimes without native PreToolUse, wrap the edit primitive through a thin script that constructs the JSON event and pipes it into the gate (same pattern as `COMMIT-GUARD-HOOK.md`).

### Bypass

`DOSSIER_TDD_GATE=off` disables the gate. Use only with written rationale in `AUDIT.md`.

### Verify the gate

Self-contained smoke test:

```bash
bash <skill-dir>/scripts/test-tdd-gate.sh
```

Exercises the five branches (unevidenced impl edit blocks, untracked test allows, meta-gate allows, test-file write allows, inactive dossier allows) in a throwaway git repo. Exits `0` on `ok`. Run after editing `tdd-gate.py` or its evidence heuristics.
