# Backprop — bug / failure -> spec memory

Backprop = reflex. Stop failed verification from forgotten. Fix code, update compact spec. Failure class harder repeat.

## When to backprop

- Narrow/adjacent verification fails.
- User reports bug during phase.
- `DRIFT-CHECK.md` finds real violation.
- Probe discovers behavior outside `§I` / `§V`.

Skip backprop for pure typos, no recurring class, unless failure cost high. Still log incident in `AUDIT.md` if phase affected.

## Loop

1. Reproduce with smallest deterministic signal.
2. Classify failure:
   - **code bug** — implementation violates current `§V` / `§I`.
   - **spec bug** — `§V` / `§I` wrong.
   - **missing invariant** — behavior unspecified but should recur.
3. Rank 3-5 falsifiable hypotheses before instrumenting.
4. Instrument one variable at time. Tag temp logs unique prefix, e.g. `[DEBUG-a4f2]`.
5. Add/update behavior test through public interface first.
6. Fix code or spec.
7. Re-run narrow verification + original repro.
8. Remove debug logs / throwaway probes.

No correct test seam = finding. Add to `AUDIT.md`, consider refactor-wave task to create seam.

## Spec updates

Check if `SPEC.md` needs updates:

- `§B`: append/update bug/finding row.
- `§V`: add new testable invariant for recurrence class.
- `§I`: amend interface when external contract wrong/incomplete.
- `§T`: add follow-up task when fix needs vertical slice.

Examples:

```text
§B row: B7|2026-04-28|refund retry double-charged|V12
§V line: V12: refund retry returns stored result, not second charge
§T row: T9|.|lock refund retry idempotency|B7|V12,I.api
```

Update `AUDIT.md` with severity, repro signal, fix notes, commit hash when landed.

## Commit shape

Backprop commit obeys dossier covenant:

```text
fix(api): replay stored refund response
```

Stage explicit paths only: spec/audit edits, test, implementation, any rebaselined recorded output.
