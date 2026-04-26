# Session handoff — compact recovery procedure

When a session crosses `/compact`, the runtime injects a
structured summary block at the top of the new context. Use it
to reconstruct in-flight state without re-reading everything.

## What the runtime gives you

A block at the top of context with these keys:

- **Last Request** — quoted user message that started the prior work.
- **Pending Tasks** — bullet list of in-flight task descriptions.
- **Files Modified** — file list (no diff content).
- **Unresolved Errors** — truncated stderr blocks from any failed background commands.
- **Git** — operations performed (diff, commit, log, status).
- **Project Rules** — path to `.claude/CLAUDE.md`.
- **Skills Used** — array of skill names invoked in the prior half.
- **Environment** — cwd at compact time, last command issued.
- **Session Intent** — short label (e.g. "review", "build", "debug").

## What survives the compact (no recovery needed)

- **Runtime task state.** Use the selected adapter's task list. If it is missing, reconstruct it from `PLAN.md`.
- **`.scratchpad/dossier/` files on disk.** Compact/session loss does not touch the filesystem.
- **Long commands.** The runtime may track sessions/background commands orthogonally.

## What does NOT survive

- **In-flight context (Read output, Bash stdout, Edit diffs).** Gone. Reconstruct from disk.
- **Loaded deferred-tool schemas.** Reload via `ToolSearch` if you need them again.

## Recovery sequence

In order:

1. **Read the `/compact` summary block** at the top of context (automatic; no tool call).
2. **`task_list`** — confirm in-flight task survived. Read its full description.
3. **Read `.scratchpad/dossier/PLAN.md`** at the phase you were in.
4. **Read `.scratchpad/dossier/AUDIT.md`** for the bug section the in-flight task references.
5. **`git log --oneline | head -<n>`** — confirm commits mentioned in the summary actually landed.
6. **`git status --short`** — see uncommitted changes (likely the WIP for the in-flight task).
7. **Resume the in-flight task** at whatever step its TDD round was on (RED, GREEN, adjacent check, land).

## What we did NOT use

These are available but were not needed for prior phase recovery:

- `episodic-memory:search-conversations` — scratchpad files + git log were enough.
- Subagent dispatch — solo session.
- MCP servers — none needed.

If the scratchpad is missing or corrupt and `git log` doesn't
reconstruct enough state, fall back to
`episodic-memory:search-conversations` for prior session
decisions.

## Within the post-compact half

Same rhythm as pre-compact:

- On phase boundary: read `PLAN.md` to pick next phase.
- On task boundary: read `AUDIT.md` section for the bug.
- In-flight: `task_list` for visibility.
- Internal record: commit log + `.scratchpad/dossier/closeout/`.

## When to write a closeout note mid-phase

Normally you write closeout only at phase close. But if compact/session
loss is imminent and there is a multi-phase milestone worth narrating,
drop a partial `.scratchpad/dossier/closeout/phase-<N>-partial.md`
(mark it WIP in the body). This reduces recovery burden.
