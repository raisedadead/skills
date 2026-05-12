# Core protocol

Dossier full-protocol only. Internal scratchpad theater for agents coordinating multi-phase work. Stays standalone: no external process framework, no public release notes, no package-manager changesets unless user explicit ask export.

## Scratchpad layout

Tiered. The minimal shape is just `SPEC.md` plus `closeout/`. Heavier flavors (migration / release-hardening) and explicit escalators (`--phases >1`, `--tasks >8`, `--findings >5`, `--legacy`) materialize the rest.

```text
.scratchpad/dossier/
  SPEC.md              # compact active state: §G/§C/§I/§V/§T/§B (always)
  PLAN.md              # narrative phase plan (escalated)
  AUDIT.md             # finding ledger with optional detail sections (escalated)
  LENS.md              # optional symlink/copy from lenses/
  closeout/
    TEMPLATE.md        # rendered for heavy flavors or --legacy
    phase-<N>-<slug>.md
```

Grow a tiered dossier later via `dossier-promote.sh --plan|--audit`.

`.scratchpad/` gitignored. Closeout note = internal phase record. Do not write dossier internals to `.changeset/`; that namespace belongs to release tooling.

## Domain awareness

Before plan or edit, silently read project domain docs when exist:

- `CONTEXT.md` at repo root, or `CONTEXT-MAP.md` for multiple contexts.
- Relevant ADRs under `docs/adr/` or context-local `docs/adr/`.

Use project vocabulary from those files in `PLAN.md`, `SPEC.md`, `AUDIT.md`, test names, commit subjects, closeout notes. If files not exist, continue without creating. Dossier only records phase state; durable product/domain docs outside its scratchpad.

## Compact active state

`SPEC.md` use fixed addressable sections:

| Section | Purpose                                                      |
| ------- | ------------------------------------------------------------ |
| `§G`    | Goal: one-line phase outcome.                                |
| `§C`    | Constraints: locked choices, covenant pointers, no-goes.     |
| `§I`    | Interfaces: external surfaces the phase may touch.           |
| `§V`    | Invariants: testable rules that must keep holding.           |
| `§T`    | Tasks: active table, status `.` todo / `~` wip / `x` done.   |
| `§B`    | Bugs/findings: compact backprop log, synced from `AUDIT.md`. |

`PLAN.md` stays narrative and phase-shaped. `SPEC.md §T` = compact active dashboard. `AUDIT.md` carries enough evidence for findings that cannot fit cleanly in `§B` table.

## Shared primitives

All core docs use runtime-neutral primitives. Selected runtime adapter map them to real tools.

| Primitive           | Meaning                                                     |
| ------------------- | ----------------------------------------------------------- |
| `task_create`       | Add one visible task per planned commit.                    |
| `task_start`        | Mark the current task in progress.                          |
| `task_done`         | Mark the current task complete.                             |
| `task_list`         | Confirm pending / in-flight / completed state.              |
| `run_command`       | Run a short foreground command.                             |
| `long_command`      | Start a command expected to exceed 30s.                     |
| `resume_after_wait` | Arrange runtime-specific continuation for `long_command`.   |
| `read_context`      | Read relevant plan, audit, spec, code, and lens sections.   |
| `edit_files`        | Apply the scoped implementation/test/documentation changes. |
| `commit_paths`      | Stage explicit paths and make the covenant commit.          |
| `handoff_summary`   | Reconstruct state after compact/session loss.               |

## Lifecycle

0. **Premise check.** Before touching `PLAN.md`, list every assumption the plan rests on — file/path exists, library exposes method `X`, schema has column `Y`, env var `Z` is set, doc claim `K` is current. Verify each empirically (`ls`, `Read`, `grep`, narrow probe, schema query). Record gaps as `C<n>` rows in `AUDIT.md`. Five minutes of probing prevents three hours of debugging the wrong tree. Skip only if every assumption is already covered by a recent verified C-row.
1. Pick a starting flavor, runtime adapter, lens. Re-flavor between phases without ceremony if the work shape shifts; lens swap is fine when secondary stack dominates a phase.
1. Initialize `.scratchpad/dossier/`.
1. Fill `PLAN.md`: phases, locked decisions, expected outcome per sub-phase (commit counts are estimates, not gates).
1. Fill `SPEC.md`: `§G`, `§C`, `§I`, `§V`, `§T`, `§B`.
1. Seed `AUDIT.md`: B-ids/C-ids, severity, symptom, reproduction signal.
1. Every planned commit: `task_start`, flip `§T` to `~`, TDD round, adjacent check, `commit_paths`, flip `§T` to `x`, `task_done`.
1. On failed verification: run `BACKPROP.md` before retry.
1. At phase boundary: run `DRIFT-CHECK.md`, update `AUDIT.md`, confirm `task_list` zero in-flight work, write closeout note.

## Non-negotiables

- One commit per task unless `PLAN.md` explicit record exception before work start.
- Commit autonomously per task; do not pause for approval between covenant commits. User-owned ops (push, PR, publish, deploy) are a one-line entry in `COVENANT.md` negative table, not a per-task gate.
- No `git add .` or `git add -A`; stage explicit paths only.
- Every implementation/config/contract change has sibling test, meta-gate, or recorded-output rebaseline in same commit.
- Tasks = vertical slices: one behavior or outcome through public interface, not one layer at a time.
- Rebaseline outputs only after read unbaselined diff.
- Long commands use selected adapter; never spin with shell `sleep`.
- Closeout stays internal unless user approve export.

## Closeout

Write `.scratchpad/dossier/closeout/phase-<N>-<slug>.md` at phase close. Must name:

- flavor, lens, phase
- commits landed
- findings closed and deferred
- verification run
- rollout / rollback / operator notes when relevant
- public artifacts still requiring user approval
