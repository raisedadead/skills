# Claude Code hook responses — literal messages + structured replies

These are observed Claude Code project-hook messages. Claude Code
provides the hook event surface; the TDD gate below is a user-installed
project hook, not a built-in Claude Code rule. Dossier ships a lightweight
implementation at `scripts/tdd-gate.py`; setup lives in
`TDD-GATE-HOOK.md`. If hook is absent, enforce same sibling-test covenant
manually.

## PreToolUse:Edit/Write — TDD gate

**Trigger:** editing an impl file with no sibling test in the
current `git diff`.

**Literal block:**

```
TDD gate: editing impl file '<path>' without a sibling test
in the current git diff. Write or update a failing test before
modifying implementation.
```

**Response (every time):**

1. Stop the impl edit.
2. Write a sibling test that asserts the rule the impl change is
   about to encode.
3. Run the test once. Confirm RED.
4. Re-attempt the impl edit. Hook accepts because the test is now
   in `git diff HEAD..HEAD` (uncommitted).

**Special case — config / threshold edits:** there is no obvious
component-test sibling. Write a **meta-test** (see `META-GATE.md`)
that reads the config and asserts the floor. The meta-test IS the
sibling.

## PostToolUse:Edit/Write — formatter (lint-staged + prettier)

**Trigger:** every successful Edit / Write that touches
a watched extension (commonly `.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.go`, `.rs`, `.css`, `.scss`, `.astro`, `.md`, `.yaml`, `.tf`, `.sql` — depends on lint-staged / pre-commit config).

**Literal block:**

```
PostToolUse:Edit hook additional context: PostToolUse hook
modified <path> after your edit (likely a formatter). Your next
Edit will not fail with a stale-file error, but if its old_string
targets a region the hook reformatted, Read the file first.
```

**Common reformats (varies by tool):**

- Prettier / oxfmt: multi-attribute JSX wraps, quote style flips, trailing newline added.
- Black / ruff: line wrapping at 88 chars, single→double quotes, import order.
- gofmt / goimports: import grouping, tab indentation.
- rustfmt: line breaks at function boundaries, trailing commas.
- terraform fmt: alignment of `=` in blocks.
- sqlfluff: keyword case + indentation.

**Response:** `Read` the file again before the next Edit on it.
The next `old_string` may otherwise match pre-format content and
fail.

## PostToolUse:Edit/Write — eslint validator warnings

**Trigger:** Edit / Write produces source that violates a linter (ESLint, ruff, golangci-lint, clippy, sqlfluff, tflint)
(unused vars, unused imports, etc.).

**Literal block:**

```
PostToolUse:Edit hook additional context: 1 validator warning(s)
this edit — see /<project>/.claude/validator-warnings.log
(Read directly, or ctx_fetch_and_index if large).
Details: eslint: 1 lines
```

**Response:** `Read` the log tail to see the literal warning.
Fix it (use the import or remove it).

## PreToolUse:Bash — cmd-git-rules

**Active throughout.** Did NOT block any compliant command. Stays
silent if you follow the rules in `COVENANT.md`. Fires on:

- `git add -A` / `git add .`
- `--no-verify` / `--no-gpg-sign`
- `git reset --hard` / `git checkout --` on tracked changes
- HEREDOC in commit messages
- backticks in commit messages (command-substitution pattern)
- `git push` / `gh pr create` (user-owned)

**Response:** never bypass. If the hook fires, the underlying
operation is wrong, not the hook.

## PostToolUseFailure:Bash — CWD-drift detector

**Trigger:** command after `cd <subdir>` references a path that
exists relative to the original cwd, not the new cwd.

**Literal block:**

```
PostToolUseFailure:Bash hook additional context: Verify the path
exists — you may be in the wrong directory.
```

**Common case:** after `cd apps/docs`, `git add apps/docs/foo`
fails because path doubles to `apps/docs/apps/docs/foo`.

**Response:** use bare relative path matching cwd
(`git add foo`) or absolute path. Avoid `cd` when possible —
use absolute paths from the original cwd.

## UserPromptSubmit — re-injections

Every user message re-injects:

- caveman mode reminder (output style)
- `cmd-git-rules` reminder
- (project-specific) dp-cto plugin reminders if installed

**Response:** these are passive reminders, not action items.
Continue the in-flight task.

## SessionStart:compact

**Trigger:** after `/compact`.

**Re-asserts:** caveman mode level, plugin warnings, plus the
structured summary block (see `HANDOFF.md`).

**Response:** read the summary block, then read
`.scratchpad/dossier/` docs to reconstruct in-flight context.

## What we did not need but the harness offers

- PreToolUse:Read context tip (suggests `ctx_execute_file` for
  analysis Reads). Honour for big-output reads; skip for
  Reads-before-Edit.
- PreToolUse:Bash context tip (suggests `ctx_batch_execute`).
  Honour for multi-command shells; skip for single git ops.
