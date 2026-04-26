# Failure modes — symptoms, causes, fixes

Catalogue of stack-neutral footguns. Each entry: trigger /
symptom / fix. No speculation. Stack-specific footguns
(SSR/hydration, jsdom shims, k8s IRSA, etc.) live in the
matching `lenses/<stack>.md`.

## Workflow / shell

### CWD drift after `cd` into subdir

- **Trigger:** after `cd apps/docs`, ran `git add apps/docs/foo`.
- **Symptom:** `fatal: pathspec 'apps/docs/foo' did not match any files`; warning about doubled path.
- **Fix:** use bare relative path matching cwd (`git add foo`) or absolute path. Avoid `cd` when possible — use absolute paths from the original cwd.

### Output truncation on big stdout

- **Trigger:** runner emits multi-MB JSON / log dump (coverage, plan diff, large fixture).
- **Symptom:** parser-wrapped command (RTK, lint reporters) drops the tail; the table / diff never reaches you.
- **Fix:** route through `rtk proxy` (or the runner's raw mode); for very large output, pipe to `tail -100` / `head -100` / `grep <key>` and read only the bracketed region.

### Workspace filter no-op

- **Trigger:** `pnpm -F docs test` when workspace name is `@scope/docs`, not `docs`.
- **Symptom:** filter matches zero packages; command silently no-ops, exit 0.
- **Fix:** use the full workspace name (`pnpm --filter @scope/docs test`) or `pnpm exec <cmd>` from the package dir. Same shape: `cargo -p`, `go work` member names, `mvn -pl`.

### `cd && cmd` tolerates partial failure

- **Trigger:** `cd subdir && cmd` where `cd` succeeds but `cmd` fails — exit code surfaces, but follow-up commands ran in the subdir.
- **Fix:** prefer absolute paths or `git -C <dir>` style flags. Reserve `cd` for interactive shells.

## TDD gate / hooks

### Gate blocks config / threshold edit

- **Trigger:** Edit a config file (`vitest.config.ts`, `pyproject.toml`, `terraform.tfvars`, `dbt_project.yml`).
- **Symptom:** PreToolUse hook blocks: "TDD gate: editing impl file `<path>` without a sibling test in the current git diff."
- **Fix:** write a meta-gate FIRST (asserts the rule the config encodes); confirm RED with current config; THEN bump the config — gate accepts because the meta-test is the sibling. See `META-GATE.md`.

### Formatter reformats between Edits

- **Trigger:** Edit / Write produces code with multiple attributes / wrappable expressions.
- **Symptom:** next Edit's `old_string` fails because the formatter wrapped attributes / changed quote style / reordered imports.
- **Fix:** `Read` the file again before the next Edit on it.

### Linter validator on unused symbol

- **Trigger:** wrote a meta-test that imported a symbol but didn't use it.
- **Symptom:** PostToolUse: `1 validator warning(s)`. Log line names the unused symbol.
- **Fix:** use the import in the body, or remove it. Don't disable the rule.

### `replace_all` over-replacement

- **Trigger:** `Edit({replace_all: true, old_string: "PANEL"})` on a file containing `PANEL_OPEN`.
- **Symptom:** `PANEL_OPEN` became `PANEL_OPEN_OPEN`.
- **Fix:** prefer narrow Edits with surrounding-context `old_string`. Use `replace_all` only when the target is unique. `replace_all` is sharp; treat it like sed.

### Commit hygiene rule fires

- **Trigger:** `git add -A`, `--no-verify`, HEREDOC in `-m`, backticks in commit subject, `git push`.
- **Symptom:** PreToolUse `cmd-git-rules` blocks.
- **Fix:** never bypass. The hook fires because the operation violates the covenant. Use explicit paths, fix the underlying hook breakage rather than skipping, and let the user own push / PR / publish.

## Test / runner

### Wrong test runner reaches the file

- **Trigger:** test file in `tests/` but the project also has `__tests__/` and the config picks one.
- **Symptom:** test runs locally with one command, fails to discover under another. CI sees zero tests.
- **Fix:** confirm the runner's discovery glob in config (`testMatch`, `testPaths`, `testfile patterns`); align placement.

### Cached test passes after source changed

- **Trigger:** stale build dir, jest cache, `dist/` not rebuilt, terraform cached plan.
- **Symptom:** test passes locally but fails in CI; or vice versa.
- **Fix:** rebuild step before test (see `OUTPUT-REBASELINE.md` step 2). Add cache-busting to the runner's CI config.

### Flaky single test

- **Trigger:** test passes 4/5 runs.
- **Anti-pattern:** raise project-wide retry count.
- **Fix:** skip + file a finding (`flaky-<name>`). Investigate. Never weaken the suite.

## Data shape / assertions

### Selector / matcher matches dead artefacts

- **Trigger:** selector matches both live output and inert artefacts (e.g. CSS class name appearing in code-sample text, log line matching multiple sources, JSON path matching example payload + actual response).
- **Symptom:** count > expected.
- **Fix:** discriminate via state attribute (`data-state="open"`, `status: "live"`), source attribution, or scope to a known live-only container.

### Long-poll / async race

- **Trigger:** test runs `fill → expect(result)` on an async system before the result lands.
- **Symptom:** flake; passes when system warm, fails on cold start.
- **Fix:** wait for the _condition_ (`expect.poll`, `Eventually`, retry-with-timeout), not a fixed delay. Probes (see `PROBE-PATTERN.md`) reveal the actual timing.

## Output / rebaseline

### Fix doesn't rebaseline because surface not recorded

- **Trigger:** changed source file produces output not in the recorded set.
- **Symptom:** rebaseline updated 3 of 10 expected goldens; looks "wrong".
- **Resolution:** recorded set is a strict subset by design. Confirm in the spec / config (e.g. `playground-card.spec.ts`, `openapi.config.ts`, `tests/golden/manifest`). If a unit _should_ be recorded but isn't, file a separate ledger entry.

### Two parallel rebaselines on overlapping artefacts

- **Trigger:** two sessions / branches both running `--update-snapshots`.
- **Symptom:** lost-update merge conflict on golden files; one set wins, the other's intent is lost.
- **Fix:** rebaselines are exclusive. Coordinate. If branches share scope, rebaseline on one branch, rebase the other onto it.

### Goldens accepted before the unbaselined diff was read

- **Trigger:** ran `--update-snapshots` reflexively on first failure.
- **Symptom:** goldens now encode the bug; CI green; user sees breakage.
- **Fix:** strict 5-step order in `OUTPUT-REBASELINE.md`. Never accept goldens before reading the unbaselined diff.

## Lens-specific footguns

Stack-specific failure modes are catalogued in the lens files
(SSR/hydration, jsdom shims, IRSA, schema NULLs, model
non-determinism, etc.). Load the matching lens for the work
in progress.
