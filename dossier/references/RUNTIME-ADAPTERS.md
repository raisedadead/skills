# Runtime adapters

Core dossier docs use shared primitives. Pick one adapter at the start and keep using it for the phase.

## Claude Code

| Primitive           | Mapping                                                       |
| ------------------- | ------------------------------------------------------------- |
| `task_create`       | `TaskCreate` one task per planned commit.                     |
| `task_start`        | `TaskUpdate({ taskId, status: "in_progress" })`.              |
| `task_done`         | `TaskUpdate({ taskId, status: "completed" })`.                |
| `task_list`         | `TaskList`; require zero in-flight at phase boundary.         |
| `long_command`      | Bash with `run_in_background: true`.                          |
| `resume_after_wait` | `ScheduleWakeup` with `<<autonomous-loop-dynamic>>`.          |
| `handoff_summary`   | Runtime compact summary + `TaskList` + scratchpad files.      |
| `spawn_review`      | `Agent` tool with `subagent_type: Explore`, read-only prompt. |

Claude Code hook details live in `HOOK-RESPONSES.md`.

## Codex

| Primitive           | Mapping                                                               |
| ------------------- | --------------------------------------------------------------------- |
| `task_create`       | `update_plan` with one item per planned commit.                       |
| `task_start`        | `update_plan` marks exactly one item `in_progress`.                   |
| `task_done`         | `update_plan` marks the item `completed`.                             |
| `task_list`         | Read the current `update_plan` state; require no `in_progress` items. |
| `long_command`      | `exec_command`; poll session id with empty `write_stdin`.             |
| `resume_after_wait` | No scheduler. Keep session alive, continue polling, or report block.  |
| `handoff_summary`   | Conversation summary + git state + `.scratchpad/dossier/` files.      |
| `spawn_review`      | Child task / nested session with read-only tool allowlist.            |

Use RTK for noisy validation commands when exact stdout is not needed. Use explicit user approval for pushes, PRs, publishes, deploys, and destructive operations.

## OpenCode

| Primitive           | Mapping                                                                     |
| ------------------- | --------------------------------------------------------------------------- |
| `task_create`       | `todowrite`: create one todo per planned commit.                            |
| `task_start`        | `todowrite`: mark exactly one todo `in_progress`.                           |
| `task_done`         | `todowrite`: mark the todo `completed`.                                     |
| `task_list`         | `todoread`; require no `in_progress` todos at phase boundary.               |
| `long_command`      | `bash` with visible output capture / terminal session.                      |
| `resume_after_wait` | Poll `bash` session if available; otherwise run a scoped check.             |
| `handoff_summary`   | Session summary + `todoread` + git state + `.scratchpad/dossier/` files.    |
| `spawn_review`      | `task` subagent with read-only permissions (no Edit / Write / Bash mutate). |

OpenCode's `task` permission launches subagents; dossier task state uses `todowrite` / `todoread`.

If a runtime lacks a primitive, write the missing state into `PLAN.md` or as a Detail section in `AUDIT.md` before continuing. Do not silently drop task state.

## Phase-close review

`spawn_review` is invoked at phase close to grade the closeout in a fresh context, separate from the agent that authored the phase. Eats the "positive bias" failure mode where a writer grades its own work.

Generate the review prompt via:

```bash
bash <skill-dir>/scripts/close-phase.sh --review [<project-root>]
```

That prints a runtime-neutral markdown prompt to stdout. Feed it to the runtime's `spawn_review` mapping. The evaluator must run with a read-only tool allowlist — never `Edit` / `Write` / mutating `Bash`.

When to invoke `spawn_review`:

- **Always** for `migration` and `release-hardening` flavors.
- **When phase > 3 commits** for `feature-wave`.
- **Optional** for small `bug-sweep` / `refactor-wave` phases — skip if the phase landed only one or two commits.
