---
name: dossier
description: >
  Standalone, stack-neutral phase workflow for multi-phase engineering.
  Opens `.scratchpad/dossier/` plan/spec/audit/closeout with compact
  `§G/§C/§I/§V/§T/§B` state, strict one-commit TDD covenant, backprop,
  drift checks, runtime adapters, and stack lenses. Use for feature
  waves, bug sweeps, migrations, refactor/release hardening, compact
  rescue, or explicit "open dossier" requests.
license: MIT
metadata:
  author: mrugesh
  version: 0.4.0
allowed-tools: Bash(git:*) Bash(mkdir:*) Bash(ls:*) Bash(grep:*) Bash(find:*) Bash(sort:*) Bash(head:*) Bash(ln:*) Bash(sed:*) Bash(bash:*) Read Write Edit
---

# dossier

Full protocol for multi-phase engineering work. Dossier keeps agent-facing plan, compact phase spec, audit ledger, selected lens, and phase closeout inside `.scratchpad/dossier/`. Does **not** write to `.changeset/`; package-manager changesets and public release notes are external artifacts needing explicit user approval.

## Runtime

Init script needs Bash 4+. Markdown templates work in Claude Code, OpenCode, Codex via runtime adapters. Claude Code gets native `TaskCreate` / `TaskUpdate` / `TaskList` and `ScheduleWakeup`; other runtimes map same primitives to own task and shell/session tools.

## When to use

Trigger when:

- Multi-phase initiative starts (>~6 tasks across distinct phases).
- Bugs / findings need one ledger across session or phase.
- User wants strict TDD covenant enforcement.
- Migration, refactor wave, release-hardening pass, or service/API redesign needs tracked phases.
- Session crosses compact / handoff, state must reconstruct from disk.
- User explicitly says "open a dossier", "phase plan", "audit ledger", "TDD this initiative", "scaffold dossier", "close the dossier".

Skip for one-shot edits, isolated bug fixes, pure research, or anything where one normal commit enough.

## Router

Pick a starting point per axis. None of these lock for the whole initiative — flavor and lens swap freely between phases when work shape shifts. Runtime adapter usually stays fixed (it's the host), but is swappable on handoff.

1. **Flavor** — read `references/FLAVORS.md`, choose: `feature-wave`, `bug-sweep`, `migration`, `refactor-wave`, `release-hardening`, or `rescue`. Default `feature-wave`.
1. **Runtime adapter** — read `references/RUNTIME-ADAPTERS.md`, map shared primitives (`task_start`, `task_done`, `long_command`, `resume_after_wait`, etc.) to Claude Code, OpenCode, or Codex.
1. **Lens** — load at most one file from `lenses/` for dominant stack. If phase spans stacks, name secondary gates in `PLAN.md`.

Then read `references/CORE.md`. Load deeper references only when phase needs them.

## Init

```bash
bash <skill-dir>/scripts/init-dossier.sh \
  --phase <number> \
  --flavor <feature-wave|bug-sweep|migration|refactor-wave|release-hardening|rescue> \
  --lens <web|backend|cli|lib|data|infra|mobile|ml|generic> \
  [--phases <N>] [--tasks <N>] [--findings <N>] [--legacy] \
  [<project-root>]
```

Tiered open. The default footprint is minimal:

| created always         | `SPEC.md`, `closeout/`                                                                                                 |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `PLAN.md` when         | `--phases > 1`, `--tasks > 8`, flavor ∈ `{migration, release-hardening}`, or `--legacy`                                |
| `AUDIT.md` when        | `--findings > 5`, flavor ∈ `{bug-sweep, migration, release-hardening}`, or `--legacy`                                  |
| `closeout/TEMPLATE.md` | flavor ∈ `{migration, release-hardening}` or `--legacy` (other flavors render the note on demand via `close-phase.sh`) |
| `LENS.md`              | `--lens` is anything other than `generic`                                                                              |

Grow a tiered dossier later with:

```bash
bash <skill-dir>/scripts/dossier-promote.sh --plan|--audit [<project-root>]
```

`--legacy` preserves the pre-tiered 4-file shape if a project depends on the old layout. `.scratchpad/` is auto-added to `.gitignore`. `closeout/` is internal theater tooling. Do not use `.changeset/` for dossier internals.

`.scratchpad/` gitignored. `closeout/` internal theater tooling. Do not use `.changeset/` for dossier internals.

## Full workflow

1. Fill `PLAN.md`: flavor, phases, locked decisions, expected commit count.
1. Fill `SPEC.md`: compact `§G`, `§C`, `§I`, `§V`, `§T`, `§B` state.
1. Seed `AUDIT.md`: known B-ids/C-ids, severity, reproduction signal.
1. Read selected `LENS.md`, if present.
1. Per planned commit:
   - `task_start`
   - flip active `§T` row from `.` to `~`
   - read relevant plan/spec/audit/lens context
   - run `references/TDD.md`: vertical RED -> GREEN -> adjacent check -> COMMIT
   - on failed verification, run `references/BACKPROP.md`
   - use `references/BG-LOOP.md` for long commands via runtime adapter
   - flip active `§T` row from `~` to `x`
   - `task_done`
1. At phase boundary:
   - run `references/DRIFT-CHECK.md`
   - update `AUDIT.md` finding table
   - confirm runtime task list zero in-flight work
   - write `.scratchpad/dossier/closeout/phase-<N>-<slug>.md`

## Autonomy

Within a phase, commit each covenant task autonomously. Rationale lives in the commit subject (`type(scope): subject`); no out-of-band approval between commits. Pause only at phase boundary or on covenant violation. User-owned ops (push, PR, publish, deploy, package-changeset export) stay user-owned per `references/COVENANT.md` negative table — stated once, not re-litigated per task.

## Source hygiene

Source files stay phase-agnostic. **Never** write phase, stage, or audit-id markers in code or test comments — `// Phase 1:`, `// Step N:`, `// Stage 3`, `// V11 (Phase 3 / A7):`, `// PH3-B7`. Phase / audit tracking lives in `.scratchpad/dossier/PLAN.md` and `AUDIT.md §B` only. Comments in source explain _why_ (workaround refs, non-obvious invariants, upstream-bug links), not _which phase_.

Optional `PreToolUse` enforcement: `references/MARKER-GUARD-HOOK.md` wires `scripts/marker-guard.py` to `Edit|Write|MultiEdit` and blocks markers before they land.

## References

Progressive disclosure — each reference names the symptom that should trigger loading it. Do not pre-load on init.

| ref                    | load when                                                                         |
| ---------------------- | --------------------------------------------------------------------------------- |
| `CORE.md`              | first read of a fresh dossier — lifecycle, primitives, non-negotiables            |
| `FLAVORS.md`           | picking the starting flavor, or re-flavoring at a phase boundary                  |
| `RUNTIME-ADAPTERS.md`  | first read, or handoff to a different host runtime                                |
| `COVENANT.md`          | first read; revisit when a covenant violation surfaces                            |
| `EXAMPLES.md`          | want per-stack phase-tail commit examples to anchor the rules                     |
| `TDD.md`               | every task; load deferred Examples / Gate-hook sections only when stuck or wiring |
| `MARKER-GUARD-HOOK.md` | wiring the phase-marker block hook                                                |
| `COMMIT-GUARD-HOOK.md` | wiring the commit covenant block hook                                             |
| `BACKPROP.md`          | test went red after impl; deciding code bug vs spec bug vs missing invariant      |
| `DRIFT-CHECK.md`       | at phase boundary, or before closeout                                             |
| `OUTPUT-REBASELINE.md` | `git diff` shows snapshot / golden / openapi / schema dump file                   |
| `META-GATE.md`         | impl edit is config / threshold / structural — needs sibling test                 |
| `BG-LOOP.md`           | long command expected to exceed ~30s                                              |
| `PROBE-PATTERN.md`     | need a throwaway probe to check runtime state                                     |
| `HANDOFF.md`           | session crosses compact / interrupted / unclear branch state                      |
| `HOOK-RESPONSES.md`    | a runtime hook emitted a literal message and you need to interpret it             |
| `FAILURE-MODES.md`     | stuck on a known footgun; want the stack-neutral failure catalogue                |

Lenses:

- `lenses/WEB-FRONTEND.md`
- `lenses/BACKEND-API.md`
- `lenses/CLI-TOOL.md`
- `lenses/LIBRARY-PACKAGE.md`
- `lenses/DATA-PIPELINE.md`
- `lenses/INFRA-IAC.md`
- `lenses/MOBILE.md`
- `lenses/ML-PIPELINE.md`

## Output contract

When dossier closes, final message must include:

1. Path to internal closeout note under `.scratchpad/dossier/closeout/`.
1. Confirm `AUDIT.md` finding table current.
1. Confirm runtime task state shows zero in-flight work.
1. Confirm final drift check ran or explicitly skipped.
1. User-owned ops still pending (push / PR / publish / deploy / changeset export) — list once, no chatter.
