---
name: dossier
description: >
  Full, stack-neutral, phase-driven engineering workflow for multi-phase
  initiatives. Opens internal scratchpad theater under
  `.scratchpad/dossier/` (`PLAN.md`, `AUDIT.md`, `SPEC.md`, optional
  `LENS.md`, and `closeout/`) and runs a strict covenant: one commit per
  task, sibling test in diff, RED -> GREEN -> COMMIT, explicit runtime
  task state, and phase closeout. Use for feature waves, bug sweeps,
  migrations, refactor waves, release hardening, rescue after compact, or
  explicit "open a dossier" requests. Full protocol only; no lite mode.
license: MIT
metadata:
  author: mrugesh
  version: "0.3.0"
allowed-tools: Bash(git:*) Bash(mkdir:*) Bash(ls:*) Bash(grep:*) Bash(find:*) Bash(sort:*) Bash(head:*) Bash(ln:*) Bash(sed:*) Bash(bash:*) Read Write Edit
---

# dossier

Full protocol for multi-phase engineering work. Dossier keeps the
agent-facing plan, audit ledger, covenant, selected lens, and phase
closeout inside `.scratchpad/dossier/`. It does **not** write to
`.changeset/`; package-manager changesets and public release notes are
external artifacts that require explicit user approval.

## Runtime

The init script needs Bash 4+. Markdown templates work in Claude Code,
OpenCode, and Codex via runtime adapters. Claude Code gets native
`TaskCreate` / `TaskUpdate` / `TaskList` and `ScheduleWakeup`; other
runtimes map the same primitives to their own task and shell/session
tools.

## When to use

Trigger this skill when:

- A multi-phase initiative starts (more than ~6 tasks across distinct phases).
- Bugs / findings need one ledger across a session or phase.
- The user wants strict TDD covenant enforcement.
- A migration, refactor wave, release-hardening pass, or service/API redesign needs tracked phases.
- Session crosses compact / handoff and state must be reconstructed from disk.
- The user explicitly says "open a dossier", "phase plan", "audit ledger", "TDD this initiative", "scaffold dossier", or "close the dossier".

Skip this skill for one-shot edits, isolated bug fixes, pure research,
or anything where one normal commit is enough.

## Router

Before work starts, pick exactly one item from each axis:

1. **Flavor** — read `references/FLAVORS.md` and choose:
   `feature-wave`, `bug-sweep`, `migration`, `refactor-wave`,
   `release-hardening`, or `rescue`.
2. **Runtime adapter** — read `references/RUNTIME-ADAPTERS.md` and map
   shared primitives (`task_start`, `task_done`, `long_command`,
   `resume_after_wait`, etc.) to Claude Code, OpenCode, or Codex.
3. **Lens** — load at most one file from `lenses/` for the dominant
   stack. If the phase spans stacks, name secondary gates in `PLAN.md`.

Then read `references/CORE.md`. Load deeper references only when the
phase needs them.

## Init

```bash
bash <skill-dir>/scripts/init-dossier.sh \
  --phase <number> \
  --flavor <feature-wave|bug-sweep|migration|refactor-wave|release-hardening|rescue> \
  --lens <web|backend|cli|lib|data|infra|mobile|ml|generic> \
  [--with-superpowers] \
  [<project-root>]
```

The script creates:

```text
.scratchpad/dossier/
  PLAN.md
  AUDIT.md
  SPEC.md
  LENS.md              # optional symlink
  closeout/
    TEMPLATE.md
```

`.scratchpad/` is gitignored. `closeout/` is internal theater tooling.
Do not use `.changeset/` for dossier internals.

## Full workflow

1. Fill `PLAN.md`: flavor, phases, locked decisions, expected commit count.
2. Seed `AUDIT.md`: known B-ids/C-ids, severity, reproduction signal.
3. Confirm `SPEC.md`: covenant, allowed scopes, phase invariants.
4. Read selected `LENS.md`, if present.
5. For each planned commit:
   - `task_start`
   - read relevant plan/audit/spec/lens context
   - run `references/TDD-ROUND.md`: RED -> GREEN -> adjacent check -> COMMIT
   - use `references/BG-LOOP.md` for long commands via the runtime adapter
   - `task_done`
6. At phase boundary:
   - update `AUDIT.md` Resolution log
   - confirm runtime task list has zero in-flight work
   - write `.scratchpad/dossier/closeout/phase-<N>-<slug>.md`
7. Hand back push / PR / publish / deploy to the user.

## References

Load on demand:

- `references/CORE.md` — shared architecture, invariants, lifecycle.
- `references/FLAVORS.md` — full protocol presets.
- `references/RUNTIME-ADAPTERS.md` — Claude Code / OpenCode / Codex primitive mapping.
- `references/COVENANT.md` — per-task positive + negative rule list.
- `references/TDD-ROUND.md` — RED -> GREEN -> COMMIT sequence.
- `references/OUTPUT-REBASELINE.md` — golden / snapshot / contract rebaseline order.
- `references/META-GATE.md` — structural invariant tests.
- `references/BG-LOOP.md` — long-command pacing across runtimes.
- `references/PROBE-PATTERN.md` — throwaway runtime probes.
- `references/HANDOFF.md` — compact / session recovery.
- `references/HOOK-RESPONSES.md` — Claude Code hook responses.
- `references/FAILURE-MODES.md` — stack-neutral footguns.
- `references/SUPERPOWERS-INTEGRATION.md` — optional composition.

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

When the dossier closes, your final message must include:

1. Path to the internal closeout note under `.scratchpad/dossier/closeout/`.
2. Confirmation that `AUDIT.md` Resolution log is current.
3. Confirmation that runtime task state shows zero in-flight work.
4. Explicit hand-back for push / PR / publish / deploy.
5. Any public release-note or package-changeset export that still needs user approval.
