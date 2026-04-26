# Core protocol

Dossier is full-protocol only. It is internal scratchpad theater for
agents coordinating multi-phase work; it does not create public release
notes or package-manager changesets unless the user explicitly asks for an
export.

## Scratchpad layout

```text
.scratchpad/dossier/
  PLAN.md
  AUDIT.md
  SPEC.md
  LENS.md              # optional symlink/copy from lenses/
  closeout/
    TEMPLATE.md
    phase-<N>-<slug>.md
```

`.scratchpad/` is gitignored. The closeout note is the internal phase
record. Do not write dossier internals to `.changeset/`; that namespace
belongs to release tooling.

## Shared primitives

All core docs use runtime-neutral primitives. The selected runtime
adapter maps them to real tools.

| Primitive             | Meaning                                                     |
| --------------------- | ----------------------------------------------------------- |
| `task_create`         | Add one visible task per planned commit.                    |
| `task_start`          | Mark the current task in progress.                          |
| `task_done`           | Mark the current task complete.                             |
| `task_list`           | Confirm pending / in-flight / completed state.              |
| `run_command`         | Run a short foreground command.                             |
| `long_command`        | Start a command expected to exceed 30s.                     |
| `resume_after_wait`   | Arrange runtime-specific continuation for `long_command`.   |
| `read_context`        | Read relevant plan, audit, spec, code, and lens sections.   |
| `edit_files`          | Apply the scoped implementation/test/documentation changes. |
| `commit_paths`        | Stage explicit paths and make the covenant commit.          |
| `handoff_summary`     | Reconstruct state after compact/session loss.               |

## Lifecycle

1. Pick flavor, runtime adapter, and lens.
2. Initialize `.scratchpad/dossier/`.
3. Fill `PLAN.md`: phases, locked decisions, expected commit count.
4. Seed `AUDIT.md`: B-ids/C-ids, severity, symptom, reproduction signal.
5. Confirm `SPEC.md`: commit format, scopes, invariants, selected gates.
6. For every planned commit: `task_start`, TDD round, adjacent check,
   `commit_paths`, `task_done`.
7. At phase boundary: update the `AUDIT.md` Resolution log, confirm
   `task_list` has zero in-flight work, write the closeout note.
8. Hand back push / PR / publish / deploy to the user.

## Non-negotiables

- One commit per task unless `PLAN.md` explicitly records an exception
  before work starts.
- No `git add .` or `git add -A`; stage explicit paths only.
- Every implementation/config/contract change has a sibling test,
  meta-gate, or recorded-output rebaseline in the same commit.
- Rebaseline outputs only after reading the unbaselined diff.
- Long commands use the selected adapter; never spin with shell `sleep`.
- Closeout stays internal unless the user approves an export.

## Closeout

Write `.scratchpad/dossier/closeout/phase-<N>-<slug>.md` at phase close.
It should name:

- flavor, lens, and phase
- commits landed
- findings closed and deferred
- verification run
- rollout / rollback / operator notes when relevant
- public artifacts still requiring user approval
