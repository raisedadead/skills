# Full-protocol flavors

Every flavor uses the full dossier protocol: `PLAN.md`, `AUDIT.md`,
`SPEC.md`, optional `LENS.md`, task state, TDD covenant, explicit commits,
Resolution log, and closeout. Flavors only change how the docs are seeded.

## `feature-wave`

Use for new user-visible capability across multiple tasks.

- `PLAN.md`: phase by user journey or surface.
- `AUDIT.md`: seed known gaps as `C<n>` capability entries plus any bugs as
  `B<n>`.
- `SPEC.md`: lock scope names, acceptance tests, and output surfaces.
- Closeout emphasis: shipped behavior and verification.

## `bug-sweep`

Use when findings already exist and the work is audit-led.

- `PLAN.md`: group by severity or surface.
- `AUDIT.md`: every task should reference an existing or newly filed B-id.
- `SPEC.md`: lock regression-test expectations and no-unrelated-refactor rule.
- Closeout emphasis: findings closed, not reproduced, or deferred.

## `migration`

Use for schema, data, infra, API, or runtime migrations.

- `PLAN.md`: include rollout order, rollback point, and blast radius.
- `AUDIT.md`: seed risks as B-ids even when they are not yet bugs.
- `SPEC.md`: lock dry-run/plan-only gates, idempotency, and rebaseline policy.
- Closeout emphasis: migration path, rollback, operator notes.

## `refactor-wave`

Use for behavior-preserving structural changes.

- `PLAN.md`: phase by module boundary or dependency direction.
- `AUDIT.md`: seed invariants that could regress.
- `SPEC.md`: lock public contract, API surface, and golden outputs before edits.
- Closeout emphasis: unchanged behavior proof and contract diffs.

## `release-hardening`

Use near a release when the goal is closing gaps, freezing outputs, and
final verification.

- `PLAN.md`: phase by gate: tests, contracts, docs, polish, final sweep.
- `AUDIT.md`: triage all open items with severity and defer rationale.
- `SPEC.md`: lock final coverage/contract/output thresholds.
- Closeout emphasis: release readiness and deferred items.

## `rescue`

Use after compact, interrupted session, failed handoff, or unclear branch
state. Rescue still resumes the full protocol.

- `PLAN.md`: identify current phase and next task.
- `AUDIT.md`: verify the active finding and Resolution log.
- `SPEC.md`: re-read covenant and runtime adapter before any edit.
- Closeout emphasis: recovered state and any uncertainty resolved.
