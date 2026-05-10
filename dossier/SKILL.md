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
  version: "0.4.0"
allowed-tools: Bash(git:*) Bash(mkdir:*) Bash(ls:*) Bash(grep:*) Bash(find:*) Bash(sort:*) Bash(head:*) Bash(ln:*) Bash(sed:*) Bash(bash:*) Read Write Edit
---

# dossier

Full protocol for multi-phase engineering work. Dossier keeps
agent-facing plan, compact phase spec, audit ledger, selected lens, and
phase closeout inside `.scratchpad/dossier/`. Does **not** write to
`.changeset/`; package-manager changesets and public release notes are
external artifacts needing explicit user approval.

## Runtime

Init script needs Bash 4+. Markdown templates work in Claude Code,
OpenCode, Codex via runtime adapters. Claude Code gets native
`TaskCreate` / `TaskUpdate` / `TaskList` and `ScheduleWakeup`; other
runtimes map same primitives to own task and shell/session
tools.

## When to use

Trigger when:

- Multi-phase initiative starts (>~6 tasks across distinct phases).
- Bugs / findings need one ledger across session or phase.
- User wants strict TDD covenant enforcement.
- Migration, refactor wave, release-hardening pass, or service/API redesign needs tracked phases.
- Session crosses compact / handoff, state must reconstruct from disk.
- User explicitly says "open a dossier", "phase plan", "audit ledger", "TDD this initiative", "scaffold dossier", "close the dossier".

Skip for one-shot edits, isolated bug fixes, pure research,
or anything where one normal commit enough.

## Router

Pick a starting point per axis. None of these lock for the whole
initiative — flavor and lens swap freely between phases when work shape
shifts. Runtime adapter usually stays fixed (it's the host), but is
swappable on handoff.

1. **Flavor** — read `references/FLAVORS.md`, choose:
   `feature-wave`, `bug-sweep`, `migration`, `refactor-wave`,
   `release-hardening`, or `rescue`. Default `feature-wave`.
2. **Runtime adapter** — read `references/RUNTIME-ADAPTERS.md`, map
   shared primitives (`task_start`, `task_done`, `long_command`,
   `resume_after_wait`, etc.) to Claude Code, OpenCode, or Codex.
3. **Lens** — load at most one file from `lenses/` for dominant
   stack. If phase spans stacks, name secondary gates in `PLAN.md`.

Then read `references/CORE.md`. Load deeper references only when
phase needs them.

## Init

```bash
bash <skill-dir>/scripts/init-dossier.sh \
  --phase <number> \
  --flavor <feature-wave|bug-sweep|migration|refactor-wave|release-hardening|rescue> \
  --lens <web|backend|cli|lib|data|infra|mobile|ml|generic> \
  [<project-root>]
```

Script creates:

```text
.scratchpad/dossier/
  PLAN.md
  AUDIT.md
  SPEC.md
  LENS.md              # optional symlink
  closeout/
    TEMPLATE.md
```

`.scratchpad/` gitignored. `closeout/` internal theater tooling.
Do not use `.changeset/` for dossier internals.

## Full workflow

1. Fill `PLAN.md`: flavor, phases, locked decisions, expected commit count.
2. Fill `SPEC.md`: compact `§G`, `§C`, `§I`, `§V`, `§T`, `§B` state.
3. Seed `AUDIT.md`: known B-ids/C-ids, severity, reproduction signal.
4. Read selected `LENS.md`, if present.
5. Per planned commit:
   - `task_start`
   - flip active `§T` row from `.` to `~`
   - read relevant plan/spec/audit/lens context
   - run `references/TDD-ROUND.md`: vertical RED -> GREEN -> adjacent check -> COMMIT
   - on failed verification, run `references/BACKPROP.md`
   - use `references/BG-LOOP.md` for long commands via runtime adapter
   - flip active `§T` row from `~` to `x`
   - `task_done`
6. At phase boundary:
   - run `references/DRIFT-CHECK.md`
   - update `AUDIT.md` finding table
   - confirm runtime task list zero in-flight work
   - write `.scratchpad/dossier/closeout/phase-<N>-<slug>.md`

## Autonomy

Within a phase, commit each covenant task autonomously. Rationale lives
in the commit subject (`type(scope): subject`); no out-of-band approval
between commits. Pause only at phase boundary or on covenant violation.
User-owned ops (push, PR, publish, deploy, package-changeset export)
stay user-owned per `references/COVENANT.md` negative table — stated
once, not re-litigated per task.

## Source hygiene

Source files stay phase-agnostic. **Never** write phase, stage, or
audit-id markers in code or test comments — `// Phase 1:`,
`// Step N:`, `// Stage 3`, `// V11 (Phase 3 / A7):`, `// PH3-B7`.
Phase / audit tracking lives in `.scratchpad/dossier/PLAN.md` and
`AUDIT.md §B` only. Comments in source explain _why_ (workaround refs,
non-obvious invariants, upstream-bug links), not _which phase_.

Optional `PreToolUse` enforcement: `references/MARKER-GUARD-HOOK.md`
wires `scripts/marker-guard.py` to `Edit|Write|MultiEdit` and blocks
markers before they land.

## References

Load on demand:

- `references/CORE.md` — shared architecture, invariants, lifecycle.
- `references/FLAVORS.md` — full protocol presets.
- `references/RUNTIME-ADAPTERS.md` — Claude Code / OpenCode / Codex primitive mapping.
- `references/COVENANT.md` — per-task positive + negative rule list.
- `references/TDD-ROUND.md` — RED -> GREEN -> COMMIT sequence.
- `references/TDD-EXAMPLES.md` — stack examples; load only when needed.
- `references/TDD-GATE-HOOK.md` — optional Claude Code hook setup.
- `references/MARKER-GUARD-HOOK.md` — optional phase-marker block hook.
- `references/BACKPROP.md` — failed verification / bug -> `§B` + `§V`.
- `references/DRIFT-CHECK.md` — read-only spec / code drift report.
- `references/OUTPUT-REBASELINE.md` — golden / snapshot / contract rebaseline order.
- `references/META-GATE.md` — structural invariant tests.
- `references/BG-LOOP.md` — long-command pacing across runtimes.
- `references/PROBE-PATTERN.md` — throwaway runtime probes.
- `references/HANDOFF.md` — compact / session recovery.
- `references/HOOK-RESPONSES.md` — Claude Code hook responses.
- `references/FAILURE-MODES.md` — stack-neutral footguns.

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
2. Confirm `AUDIT.md` finding table current.
3. Confirm runtime task state shows zero in-flight work.
4. Confirm final drift check ran or explicitly skipped.
5. User-owned ops still pending (push / PR / publish / deploy / changeset export) — list once, no chatter.
