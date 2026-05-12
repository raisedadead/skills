# Full-protocol flavors

Every flavor uses full dossier protocol: `PLAN.md`, `AUDIT.md`, compact `SPEC.md`, optional `LENS.md`, task state, TDD covenant, explicit commits, drift check, closeout. Flavors only change how docs seeded.

## `feature-wave`

Use for new user-visible capability across multiple tasks.

- `PLAN.md`: phase by user journey or surface.
- `AUDIT.md`: seed known gaps as `C<n>` capability entries plus any bugs as `B<n>`.
- `SPEC.md`: `§G` names journey, `§I` names output surfaces, `§T` uses vertical slices, `§V` locks acceptance tests.
- Closeout emphasis: shipped behavior, verification.

## `bug-sweep`

Use when findings exist, work audit-led.

- `PLAN.md`: group by severity or surface.
- `AUDIT.md`: every task references existing or newly filed B-id.
- `SPEC.md`: `§B` mirrors active bugs, `§V` locks regression-test expectations, `§C` locks no-unrelated-refactor rule.
- Closeout emphasis: findings closed, not reproduced, or deferred.

## `migration`

Use for schema, data, infra, API, runtime migrations.

- `PLAN.md`: include rollout order, rollback point, blast radius.
- `AUDIT.md`: seed risks as B-ids even when not yet bugs.
- `SPEC.md`: `§C` locks dry-run/plan-only gates, `§V` locks idempotency and rebaseline policy, `§I` names migrated surfaces.
- Closeout emphasis: migration path, rollback, operator notes.

## `refactor-wave`

Use for behavior-preserving structural changes.

- `PLAN.md`: phase by module boundary or dependency direction.
- `AUDIT.md`: seed invariants that could regress.
- `SPEC.md`: `§I` freezes public contract/API surface, `§V` freezes golden output and behavior invariants before edits.
- Closeout emphasis: unchanged behavior proof, contract diffs.

## `release-hardening`

Use near release when goal is closing gaps, freezing outputs, final verification.

- `PLAN.md`: phase by gate: tests, contracts, docs, polish, final sweep.
- `AUDIT.md`: triage all open items with severity and defer rationale.
- `SPEC.md`: `§V` locks final coverage/contract/output thresholds; `§T` orders final sweep.
- Closeout emphasis: release readiness, deferred items.

## `rescue`

Use after compact, interrupted session, failed handoff, or unclear branch state. Rescue still resumes full protocol.

- `PLAN.md`: identify current phase, next task.
- `SPEC.md`: re-read active `§T`, `§B`, covenant constraints, runtime adapter before any edit.
- `AUDIT.md`: verify active finding table against git status/log.
- Closeout emphasis: recovered state, uncertainty resolved.

## Phase-close review (`spawn_review`)

`bash scripts/close-phase.sh --review` emits a runtime-neutral review prompt the operator hands to a fresh read-only evaluator. When to use:

| flavor              | review recommendation                                           |
| ------------------- | --------------------------------------------------------------- |
| `migration`         | **Always.** Risk is high.                                       |
| `release-hardening` | **Always.** Final pass before ship.                             |
| `feature-wave`      | When the phase landed more than ~3 commits.                     |
| `bug-sweep`         | Optional. Skip for one- or two-commit sweeps.                   |
| `refactor-wave`     | Optional, but useful if §I (contract surface) was touched.      |
| `rescue`            | Optional. Skip if rescue itself amounted to reading + resuming. |
