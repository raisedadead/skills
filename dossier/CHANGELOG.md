# Changelog

Each entry cites the failure that earned the rule (see `references/HARNESS-RATCHET.md`). Versions follow the `SKILL.md` frontmatter.

## 0.5.0 — 2026-05-12

Harness-engineering redesign. Discipline shift: enforcement over prose, scripts over recipes, splits over self-grading, progressive disclosure with concrete triggers over undifferentiated bullet lists.

### Added

- `scripts/detect-lens.sh` — sniffs a project for lens recommendation with explicit confidence band. [earned-by: operators picking the wrong lens at init, then suffering the wrong runner table all phase.]
- `scripts/dossier-status.sh` — ≤12-line banner from SPEC + git for post-compact recovery. [earned-by: re-grokking the §G/§T/§B cipher by hand every time a session crossed compact.]
- `scripts/drift-check.sh` — deterministic phase-marker grep, in-flight §T detection, open §B count, `--strict` for CI use. Replaces a prose recipe with a tool. Scans both tracked and untracked files. [earned-by: drift recipes silently skipped; WIP files with leaked phase markers landing.]
- `scripts/close-phase.sh` — renders closeout note from disk; fills Commits Landed / Findings Closed / Deferred sections; `--review` emits a runtime-neutral review prompt. [earned-by: hand-written closeout prose drifting from git log; closeout's "Findings Closed" not matching §B reality.]
- `scripts/preflight.sh` — premise-check checklist emitter for the step CORE called out as "five minutes prevents three hours". [earned-by: plans built on unverified premises (file paths, library methods, schema columns) that fail mid-phase.]
- `scripts/lesson.sh` — append / list / retire entries in `.scratchpad/dossier/.lessons.md`. Per-project default; `--lessons-home` for kernel-wide store. [earned-by: rediscovering the same trap multiple phases in a row.]
- `scripts/commit-guard.py` — PreToolUse hook on Bash blocking nine commit-covenant violations: `git add .`, `--no-verify`, `--no-gpg-sign`, `git push`, `gh pr create`, `git reset --hard` on dirty tree, `git commit --amend` after push, HEREDOC in `-m`, backticks in `-m`. Standalone — no kernel dependency. [earned-by: each rule was a real past violation in COVENANT.md's negative table that the prose alone failed to prevent.]
- `scripts/post-commit-test.py` — PostToolUse hook running a project-supplied `.scratchpad/dossier/test-runner.sh` against the last commit's changed files. Silent on green, verbose stderr on red. Default OFF. [earned-by: "all green at task_done, red at drift-check" gap — silent failures discovered only at phase boundary.]
- `scripts/migrate-audit.sh` — ports legacy `AUDIT.md §B` rows into the new SPEC-canonical `§B`. [earned-by: two parallel finding schemas in COVENANT.md / SPEC.md.tmpl / AUDIT.md.tmpl that never stayed in sync.]
- `scripts/dossier-promote.sh` — materializes PLAN.md / AUDIT.md in a tiered dossier when scope grows post-init. [earned-by: binary "full 4-file open or nothing" gating most small phases out of using dossier at all.]
- `references/COMMIT-GUARD-HOOK.md` — runtime-neutral wiring doc (Claude Code / OpenCode / Codex).
- `references/POST-COMMIT-HOOK.md` — runtime-neutral wiring doc.
- `references/HARNESS-RATCHET.md` — this discipline, named.
- `references/EXAMPLES.md` — extracted per-stack phase-tail examples from COVENANT.md, now deferred.
- `references/TDD.md` — merged `TDD-ROUND` + `TDD-EXAMPLES` + `TDD-GATE-HOOK` into one file with deferred sections + a new "Read order — keep the prompt cache warm" clause. [earned-by: agents defensively pre-loading the three TDD files even on trivial rounds; cache miss every round because reads weren't in a stable order.]
- `--review` / `--review-out` on `close-phase.sh` and a `spawn_review` runtime primitive in `RUNTIME-ADAPTERS.md`. [earned-by: same-agent self-grading at phase close producing inflated PASS verdicts.]
- `--lessons-home` / `--lessons-recent` on `init-dossier.sh`; surfaces last N lesson rows as a "Lessons brought forward" section in fresh SPEC.md. [earned-by: lessons file existing but never feeding back into dossiers.]
- `--phases` / `--tasks` / `--findings` / `--legacy` on `init-dossier.sh` — tiered open. Default footprint is now SPEC.md + closeout/ only. [earned-by: ceremony pushing operators to skip dossier on medium-size work.]

### Changed

- `SPEC.md §B` is now the **canonical** finding ledger. `AUDIT.md` template drops its 8-column §B table; the file keeps only optional per-finding Detail sections. [earned-by: two parallel §B schemas drifting out of sync — a synchronization failure mode baked into the prior templates.]
- `SKILL.md` references list replaced by a trigger-symptom routing table (one row per ref, "load when…"). \[earned-by: agents defensively over-reading the load-on-demand list because it didn't actually say *when* to load each file.\]
- `references/HANDOFF.md` neutralized: removed personal MCP and Claude-Code-only assumptions; runtime-neutral wording for cross-session memory search. [earned-by: skill needs to ship to operators using OpenCode / Codex / other hosts.]
- `init-dossier.sh` `--legacy` flag preserves the pre-tiered 4-file shape for projects pinned to the old layout.

### Removed

- `references/TDD-ROUND.md` — merged into `TDD.md`.
- `references/TDD-EXAMPLES.md` — merged into `TDD.md` (deferred section).
- `references/TDD-GATE-HOOK.md` — merged into `TDD.md` (deferred section).
- Worked-examples block from `COVENANT.md` — moved to `EXAMPLES.md` (deferred).

### Fixed

- `drift-check.sh` scans untracked files too via `git ls-files --cached --others --exclude-standard`. \[earned-by: initial implementation used bare `git ls-files`, missing WIP files where phase markers most often leak.\]

## 0.4.0 — initial release

Standalone, stack-neutral phase workflow. `PLAN.md` / `SPEC.md` / `AUDIT.md` / optional `LENS.md` under `.scratchpad/dossier/`, runtime adapters for Claude Code / OpenCode / Codex, per-task TDD covenant, `tdd-gate.py` and `marker-guard.py` PreToolUse hooks.
