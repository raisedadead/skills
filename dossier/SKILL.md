---
name: dossier
description: >
  Stack-neutral, file-based, phase-driven workflow for any
  multi-phase engineering initiative — frontend, backend, CLI,
  library, mobile, data pipeline, infrastructure, ML. Opens a
  "dossier" of three living markdown docs (`AUDIT.md` bug ledger,
  `PLAN.md` phase plan, `SPEC.md` covenant + invariants) under
  `.dossier/` plus a committed `.changeset/` durable record.
  Enforces a per-task covenant — exactly one commit per task,
  sibling test in `git diff`, conventional `type(scope): subject
  (P<N>-Bxx)` format — and the canonical RED → GREEN → COMMIT TDD
  round. Long-running commands run in background + ScheduleWakeup
  pacing. `/compact` recovers in-flight state from on-disk
  artefacts. Composes cleanly with `obra/superpowers`: use
  superpowers for brainstorm/plan/dispatch/review/worktrees;
  layer dossier on top for the durable ledger, sibling-test gate,
  commit cadence, wakeup pacing, and compact recovery. Ships a
  `lenses/` directory with stack-specific addons (web frontend,
  backend API, CLI tool, library/package, data pipeline,
  infra/IaC, mobile, ML pipeline) — the agent reads core +
  applicable lens. Replaces heavyweight stage-based plugins
  (dp-cto, dp-cab) with plain markdown + native TaskCreate /
  TaskUpdate / TaskList. Example triggers: "open a dossier",
  "start a phase plan", "TDD this with a covenant", "audit
  ledger for these bugs", "schema migration plan", "service
  refactor wave", "library release plan", "API redesign with
  ledger", "CLI tool refactor", "infra rollout phases", "data
  pipeline migration", "scaffold .dossier/", "lightweight epic
  workflow", "replace dp-cto with markdown", "rebuild context
  after compact", "close the dossier — write the changeset".
license: MIT
metadata:
  author: mrugesh
  version: "0.2.0"
compatibility: Bash 4+ (init script). Markdown templates work in any agent. Native TaskCreate / TaskUpdate / TaskList and ScheduleWakeup require Claude Code runtime; fall back to a manual checklist on other runtimes. Composes with obra/superpowers (optional).
allowed-tools: Bash(git:*) Bash(mkdir:*) Bash(ls:*) Bash(grep:*) Bash(bash:*) Read Write Edit
---

# dossier

Stack-neutral, file-based, phase-driven engineering workflow.
Opens a **dossier** — three living markdown docs in `.dossier/`
plus a committed `.changeset/` for the durable story — and walks
each task through a TDD covenant with one commit per task.

Works for any multi-phase initiative: web frontend, backend
service, CLI tool, library/SDK, mobile app, data pipeline,
infrastructure rollout, ML pipeline. Stack-specific patterns
live in `lenses/`; load only the one(s) relevant to the work.

## When to use

Trigger this skill when:

- A multi-phase initiative starts (more than ~6 tasks across distinct phases).
- Bugs / findings accumulate across a session and need a single ledger.
- The user wants TDD covenant enforced (one commit per task, sibling test in diff, conventional commit format).
- A long-running command (build, full test suite, migration apply, plan/diff, model train) needs background + ScheduleWakeup pacing.
- Session crosses `/compact` and context must be reconstructed from durable artefacts.
- The user explicitly says: "open a dossier", "phase plan", "audit ledger", "TDD this initiative", "scaffold .dossier/", "replace dp-cto / dp-cab".

Skip this skill for:

- One-shot edits, single-file refactors, isolated bug fixes.
- Pure research / read-only spelunking.
- Anything where one commit suffices and there is no phase structure.

## Architecture (three layers, two locations)

| Layer     | Location                           | Lifetime          | Purpose                                                                |
| --------- | ---------------------------------- | ----------------- | ---------------------------------------------------------------------- |
| Audit     | `.dossier/AUDIT.md`                | session / phase   | Finding ledger. One section per finding. Status legend, severity, fix. |
| Plan      | `.dossier/PLAN.md`                 | session / phase   | Phase plan. Locked decisions at top, phases below.                     |
| Spec      | `.dossier/SPEC.md`                 | session / phase   | Per-task covenant + invariants. Read once at start.                    |
| Lens      | `.dossier/LENS.md` (symlink)       | session / phase   | One stack lens copied/symlinked from `lenses/`. Optional.              |
| In-flight | TaskCreate / TaskUpdate / TaskList | this session      | Visible queue + state. Survives `/compact`.                            |
| Durable   | `.changeset/<slug>.md`             | committed forever | Release-note narrative. Source of truth for what shipped.              |

`.dossier/` is gitignored. `.changeset/` is committed.

> **Compat note.** Earlier versions of this skill used `.scratchpad/`. If migrating, rename the directory and update `.gitignore`. The semantics are identical.

## Composition with obra/superpowers (optional)

The `obra/superpowers` plugin owns: `brainstorming`,
`writing-plans`, `subagent-driven-development`,
`requesting-code-review`, `using-git-worktrees`,
`finishing-a-development-branch`. It writes plan docs to
`docs/superpowers/plans/<date>-<feature>.md`.

Dossier owns: durable ledger (`AUDIT.md`), per-task covenant
(`SPEC.md`), sibling-test TDD gate, commit cadence, ScheduleWakeup
pacing, on-disk `/compact` recovery, durable `.changeset/`.

When both are installed, run the init script with
`--with-superpowers` to point `.dossier/PLAN.md` at superpowers'
plan dir (symlink). One plan file, two sets of conventions. See
`references/SUPERPOWERS-INTEGRATION.md`.

## Workflow

### 0. Init (one-time per project)

```bash
bash <skill-dir>/scripts/init-dossier.sh \
  --phase <number> \
  --lens <web|backend|cli|lib|data|infra|mobile|ml|generic> \
  [--with-superpowers] \
  [<project-root>]
```

Or manually:

1. `mkdir -p .dossier`
2. Add `.dossier/` to `.gitignore` if missing.
3. Copy `assets/templates/{AUDIT,PLAN,SPEC}.md.tmpl` into `.dossier/` (drop the `.tmpl`).
4. Pick a changeset template variant: `changeset-package.md.tmpl` (semver / monorepo) or `changeset-service.md.tmpl` (service / app).
5. (Optional) symlink `lenses/<stack>.md` to `.dossier/LENS.md`.

### 1. Author docs (before work starts)

- Fill `PLAN.md`: phases, locked decisions, expected commit count per phase.
- Pre-seed `AUDIT.md` with known findings (B1, B2, …) at status `[ ]`, severity P1-P4.
- Confirm `SPEC.md` covenant matches the phase's constraints (see `references/COVENANT.md`).
- Read the lens (if any) for stack-specific gates and rebaseline patterns.

### 2. Per-phase loop

For each phase in `PLAN.md`:

1. **TaskCreate** one task per planned commit.
2. For each task (lowest ID first):
   1. **TaskUpdate** → `in_progress`.
   2. Read the relevant `AUDIT.md` section (use `offset` + `limit` for big files).
   3. Run the **TDD round**: RED → GREEN → COMMIT. See `references/TDD-ROUND.md`.
   4. Long commands run in **background + ScheduleWakeup**. See `references/BG-LOOP.md`.
   5. **TaskUpdate** → `completed`.

### 3. Phase boundary

- Append to `AUDIT.md` Resolution log: `| B<n> | closed | <commit> | <note> |`.
- `TaskList` to confirm zero in-flight.
- Read `PLAN.md` for next phase.

### 4. Dossier close

- Write `.changeset/<phase-slug>.md` (see `assets/templates/changeset-*.md.tmpl`).
- Single commit: `chore: changeset for Phase <N> (P<N>-final)`.
- Hand back to user for push / PR / publish (never automated — see `references/COVENANT.md`).

## Hook awareness

The harness fires hooks during this workflow. See
`references/HOOK-RESPONSES.md` for literal messages and response
patterns. Key ones:

- **PreToolUse TDD gate** — blocks Edit on impl files when no sibling test in `git diff`. Response: write a failing test first.
- **PostToolUse formatter** — reformats files after Edit / Write. Response: `Read` again before next Edit on the same file.
- **PreToolUse cmd-git-rules** — enforces commit hygiene. Response: never bypass.
- **PostToolUseFailure CWD-drift** — fires after `cd` changes shell context. Response: use absolute or bare relative paths.

## Reference material (load on demand)

Core (stack-neutral):

- `references/COVENANT.md` — per-task positive + negative rule list.
- `references/TDD-ROUND.md` — RED → GREEN → COMMIT canonical sequence (multi-stack examples).
- `references/PROBE-PATTERN.md` — throwaway runtime probes for unclear failures.
- `references/OUTPUT-REBASELINE.md` — golden-file workflows: snapshots, OpenAPI dumps, terraform plan, SQL diffs, CLI stdout.
- `references/META-GATE.md` — defense-in-depth invariants (dependency pin, API surface, env contract, threshold floors, …).
- `references/BG-LOOP.md` — background command + ScheduleWakeup pacing.
- `references/HOOK-RESPONSES.md` — literal hook messages + response patterns.
- `references/HANDOFF.md` — `/compact` recovery procedure.
- `references/FAILURE-MODES.md` — common cross-stack footguns.
- `references/SUPERPOWERS-INTEGRATION.md` — composition with obra/superpowers.

Lenses (load the one matching the work):

- `lenses/WEB-FRONTEND.md` — Playwright snapshots, hydration, SSR, jsdom, CSS gates.
- `lenses/BACKEND-API.md` — OpenAPI freeze, contract tests, DB migration, idempotency.
- `lenses/CLI-TOOL.md` — golden stdout, exit-code matrix, fixture-driven specs.
- `lenses/LIBRARY-PACKAGE.md` — public API surface freeze, semver gates, type contracts.
- `lenses/DATA-PIPELINE.md` — schema gates, fixture roundtrip, idempotency, lineage.
- `lenses/INFRA-IAC.md` — plan-only diff, drift detection, dry-run gates.
- `lenses/MOBILE.md` — sim/device runs, snapshot patterns, native test layers.
- `lenses/ML-PIPELINE.md` — eval-set gates, regression bands, fixture determinism.

## Output contract

When the dossier closes, your final message must include:

1. Path to the `.changeset/<slug>.md` you wrote.
2. The commit hash of the changeset commit.
3. Confirmation that `AUDIT.md` Resolution log is current.
4. Confirmation that `TaskList` shows zero in-flight.
5. Explicit hand-back for push / PR / publish (the user owns these).
