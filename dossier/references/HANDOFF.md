# Session handoff — compact recovery procedure

When session cross `/compact`, runtime inject structured summary block at top of new context. Use it to reconstruct in-flight state without re-read everything.

## What the runtime gives you

Block at top of context with these keys:

- **Last Request** — quoted user message that started prior work.
- **Pending Tasks** — bullet list of in-flight task descriptions.
- **Files Modified** — file list (no diff content).
- **Unresolved Errors** — truncated stderr blocks from failed background commands.
- **Git** — operations performed (diff, commit, log, status).
- **Project Rules** — path to `.claude/CLAUDE.md`.
- **Skills Used** — array of skill names invoked in prior half.
- **Environment** — cwd at compact time, last command issued.
- **Session Intent** — short label (e.g. "review", "build", "debug").

## What survives the compact (no recovery needed)

- **Runtime task state.** Use selected adapter's task list. If missing, reconstruct from `PLAN.md`.
- **`.scratchpad/dossier/` files on disk.** Compact/session loss not touch filesystem.
- **Long commands.** Runtime may track sessions/background commands orthogonally.

## What does NOT survive

- **In-flight context (Read output, Bash stdout, Edit diffs).** Gone. Reconstruct from disk.
- **Loaded deferred-tool schemas.** Reload via `ToolSearch` if need again.

## Recovery sequence

In order:

1. **Read `/compact` summary block** at top of context (automatic; no tool call).
2. **`task_list`** — confirm in-flight task survived. Read full description.
3. **Read `.scratchpad/dossier/PLAN.md`** at phase you were in.
4. **Read `.scratchpad/dossier/AUDIT.md`** for finding row/detail in-flight task references.
5. **`git log --oneline | head -<n>`** — confirm commits in summary landed.
6. **`git status --short`** — see uncommitted changes (likely WIP for in-flight task).
7. **Resume in-flight task** at whatever step its TDD round was on (RED, GREEN, adjacent check, land).

## What we did NOT use

Available but not needed for prior phase recovery:

- `episodic-memory:search-conversations` — scratchpad files + git log enough.
- Subagent dispatch — solo session.
- MCP servers — none needed.

If scratchpad missing/corrupt and `git log` not reconstruct enough state, fall back to `episodic-memory:search-conversations` for prior session decisions.

## Within the post-compact half

Same rhythm as pre-compact:

- On phase boundary: read `PLAN.md` to pick next phase.
- On task boundary: read `SPEC.md §T` plus matching `AUDIT.md` finding.
- In-flight: `task_list` for visibility.
- Internal record: commit log + `.scratchpad/dossier/closeout/`.

## When to write a closeout note mid-phase

Normally write closeout only at phase close. But if compact/session loss imminent and multi-phase milestone worth narrating, drop partial `.scratchpad/dossier/closeout/phase-<N>-partial.md` (mark WIP in body). Reduces recovery burden.
