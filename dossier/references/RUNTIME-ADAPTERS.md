# Runtime adapters

Core dossier docs use shared primitives. Pick one adapter at the start and
keep using it for the phase.

## Claude Code

| Primitive           | Mapping                                                        |
| ------------------- | -------------------------------------------------------------- |
| `task_create`       | `TaskCreate` one task per planned commit.                      |
| `task_start`        | `TaskUpdate({ taskId, status: "in_progress" })`.               |
| `task_done`         | `TaskUpdate({ taskId, status: "completed" })`.                 |
| `task_list`         | `TaskList`; require zero in-flight at phase boundary.          |
| `long_command`      | Bash with `run_in_background: true`.                           |
| `resume_after_wait` | `ScheduleWakeup` with `<<autonomous-loop-dynamic>>`.           |
| `handoff_summary`   | Runtime compact summary + `TaskList` + scratchpad files.       |

Claude Code hook details live in `HOOK-RESPONSES.md`.

## Codex

| Primitive           | Mapping                                                               |
| ------------------- | --------------------------------------------------------------------- |
| `task_create`       | `update_plan` with one item per planned commit.                       |
| `task_start`        | `update_plan` marks exactly one item `in_progress`.                   |
| `task_done`         | `update_plan` marks the item `completed`.                             |
| `task_list`         | Read the current `update_plan` state; require no `in_progress` items. |
| `long_command`      | `exec_command` with PTY/session when useful; poll via `write_stdin`.  |
| `resume_after_wait` | No scheduler. Keep session alive, continue polling, or report block.  |
| `handoff_summary`   | Conversation summary + git state + `.scratchpad/dossier/` files.      |

Use RTK for noisy validation commands when exact stdout is not needed.
Use explicit user approval for pushes, PRs, publishes, deploys, and
destructive operations.

## OpenCode

| Primitive           | Mapping                                                                  |
| ------------------- | ------------------------------------------------------------------------ |
| `task_create`       | Native todo/task list entry per planned commit.                          |
| `task_start`        | Mark the active todo/task in progress.                                   |
| `task_done`         | Mark the active todo/task done.                                          |
| `task_list`         | Native todo/task list; require no in-flight items at phase boundary.     |
| `long_command`      | Native shell/session command with visible output capture.                |
| `resume_after_wait` | Native session wait/resume mechanism if available; otherwise poll once. |
| `handoff_summary`   | Native session summary + git state + `.scratchpad/dossier/` files.       |

If a runtime lacks a primitive, write the missing state into `PLAN.md` or
`AUDIT.md` before continuing. Do not silently drop task state.
