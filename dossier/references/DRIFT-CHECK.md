# Drift check — read-only spec / code report

Drift check diagnostic. Writes nothing. Finds real work,
record in `AUDIT.md` or fix via normal TDD round.

## Load

Read:

1. `.scratchpad/dossier/SPEC.md`
2. `.scratchpad/dossier/AUDIT.md`
3. `.scratchpad/dossier/PLAN.md`
4. `.scratchpad/dossier/LENS.md`, if present
5. Current git status + relevant code/tests

## Check `§V` invariants

Each invariant:

1. Translate to verifiable claim about code/tests.
2. Locate file:line evidence.
3. Classify:
   - **HOLD** — evidence supports.
   - **VIOLATE** — code/test contradicts.
   - **UNVERIFIABLE** — no good evidence.

`UNVERIFIABLE` usually coverage gap. File/update finding
instead of declaring phase clean.

## Check `§I` interfaces

Each surface:

- **MATCH** — impl shape equals spec.
- **DRIFT** — impl exists but shape differs.
- **MISSING** — spec names surface absent from code.
- **EXTRA** — code exposes relevant surface not in spec.

Use lenses for stack-specific surfaces: routes, commands, exports,
schemas, snapshots, IaC resources, model artifacts, screens.

## Check `§T` task state

Each task row:

- `x`: verify claimed behavior exists + has sibling test/recorded output.
- `~`: confirm truly in progress, runtime task state agrees.
- `.`: confirm pending work still relevant.

Flag completed rows without evidence as **STALE**.

## Report shape

Keep report compact:

```text
## Drift check

§V
V4 HOLD: tests/meta/no-shell-sleep.test.ts:22
V8 VIOLATE: src/orders/retry.ts:91 lacks idempotency key check
V9 UNVERIFIABLE: no test covers expired-token boundary

§I
I.api DRIFT: POST /orders returns `{result}` not `{id}`. routes.ts:144

§T
T3 STALE: marked x, but no behavior test or code path found

summary: 2 violate, 1 drift, 1 stale, 1 unverifiable
next: update AUDIT.md, then TDD round or BACKPROP.md
```

## Remedies

- **VIOLATE / DRIFT** — fix code or run `BACKPROP.md` if spec missed
  recurrence class.
- **MISSING** — add task in `§T` or amend `§I` if surface no
  longer wanted.
- **EXTRA** — document in `§I` or remove code.
- **STALE** — reopen task or add missing evidence.
- **UNVERIFIABLE** — add behavior test, meta-gate, or recorded-output
  check.

No edit files during drift check. End with report + next narrow action.
