# TDD round — RED → GREEN → COMMIT

Canonical sequence per task in phase. Two flavours:

- **True RED-then-GREEN** — behaviour wrong; test fail first, impl fix turn green.
- **Coverage-only round** — behaviour correct; test lock coverage/contract. Tests pass first run.

Both same shape, any stack.

## Test quality rules

- Test behavior via public interfaces, not impl details.
- One vertical tracer bullet at a time: one behavior -> one test -> one impl step.
- No write all tests first then all impl. Horizontal slice = brittle imagined tests.
- Prefer integration-style tests, survive internal refactors.
- Mock only true external boundaries. No mock internal collaborators just to assert call counts.
- Test names + task subjects use project vocab from `CONTEXT.md` / ADRs when docs exist.

## Sequence (stack-neutral)

```
task_start

# Read context
Read <impl file>
Read <existing test file (if any)>
Read <SPEC.md §T/§V/§I rows>
Read <audit finding>            # .scratchpad/dossier/AUDIT.md row/detail

# RED
Write <new sibling test file>   # one behavior through public interface
run_command: <narrow test run>  # confirm RED (or coverage-only PASS)

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

If verification fail, no retry blind. Use `BACKPROP.md` to decide: code bug, spec bug, or missing invariant. Resume round with updated evidence.

## Examples

Need concrete web/backend/CLI/meta-gate examples? Read
`TDD-EXAMPLES.md`. Do not load it for routine rounds.

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
