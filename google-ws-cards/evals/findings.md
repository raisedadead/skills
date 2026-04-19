# Eval findings — run 1 (2026-04-19)

## Results

| ID    | Prompt                        | Expected template | Result | Template picked   | Validator | Output contract |
| ----- | ----------------------------- | ----------------- | ------ | ----------------- | --------- | --------------- |
| st-01 | v2.3 release announcement     | announcement.json | PASS   | announcement.json | OK        | complete        |
| st-02 | PTO dialog                    | form.json         | PASS\* | dialog.json       | OK        | complete        |
| st-03 | API health dashboard          | dashboard.json    | PASS   | dashboard.json    | OK        | complete        |
| st-04 | Expense approval              | approval.json     | PASS   | approval.json     | OK        | complete        |
| st-05 | DB failover pager             | alert.json        | PASS   | alert.json        | OK        | complete        |
| st-06 | Gmail add-on contextual (DSL) | custom shorthand  | PASS   | n/a (DSL path)    | OK        | complete        |
| st-07 | Validate + fix broken JSON    | n/a               | PASS   | n/a (fix only)    | OK        | complete        |

\* st-02: picked `dialog.json` over `form.json`. Defensible — user said "dialog" and dialog.json uses `fixedFooter`. No rubric deduction.

## Signals collected

### Fixed this pass

- **`validate.py` / `build.py` had no positional arg** (3 agents bumped into this — `validate.py card.json` errored, had to discover `--input`). **Fix**: added positional `path` alias. Re-smoke tested with both forms.
- **Icon color promise** — st-03 noted CardsV2 `Icon` has no tint field, so "green status" is not natively expressible. Agents workaround with `materialIcon` fill variant. **Fix**: gotcha added to SKILL.md.
- **`knownIcon` catalog opaque** — st-04 guessed `DOLLAR` / `RESTAURANT` without checking. Validator does not enforce the enum. **Fix**: added link to Google's [KnownIcon ref](https://developers.google.com/workspace/chat/api/reference/rest/v1/cards#knownicon) in SKILL.md gotchas.

### Deferred (weak signal / feature, not bug)

- `approval.json` ships with extra "Open in browser" button agents had to prune. Normal template trimming; could split into `-minimal` variant if repeats.
- Shorthand DSL lacks `materialIcon.fill` / `weight` / `grade` shortcuts — feature request.
- No "pager" / "on-call" in description's example triggers. Agents still resolved correctly via "incident/failure alert".

## Run again after changes?

No need — all three concrete fixes land in docs or CLI. Re-run only after next material skill change.

## Next

Triggering eval (should_trigger=false cases sn-01..sn-05) requires real installed skill + fresh session — defer until skill is symlinked.
