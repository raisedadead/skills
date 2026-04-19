# google-ws-cards eval rubric

## Triggering (for `should_trigger=true` prompts)

| Signal          | Pass condition                                                |
| --------------- | ------------------------------------------------------------- |
| Skill invoked   | Agent reads `SKILL.md` or cites skill name before authoring   |
| Template picked | Matches `expected_template` (or documents why it deviated)    |
| Validator run   | `scripts/validate.py` executed on final JSON, returned `OK`   |
| Output contract | JSON block + format label + UIkit Builder URL + `OK` evidence |

## Triggering (for `should_trigger=false` prompts)

Skill must **not** fire. Agent should answer the request on its own merits without loading `SKILL.md` or authoring CardsV2 JSON.

## Output quality (for card authoring)

| Lens          | Criterion                                                                  |
| ------------- | -------------------------------------------------------------------------- |
| Schema        | Only valid widget keys, single widget-type per widget object               |
| URLs          | All `imageUrl` / `iconUrl` / header `imageUrl` use `https://`              |
| Envelope      | Correct format for target (card / message / addon)                         |
| Required keys | `cardId` present + regex-valid in message envelope; `header.title` if used |
| Limits        | ≤ 100 widgets, ≤ 2 `columnItems`                                           |
| Interactivity | Buttons with `action` include `function` string, params as `{key, value}`  |

## Scoring

- **Pass** — all rows hit
- **Weak pass** — skill fired + output valid, but wrong template or missing output-contract element
- **Fail** — skill didn't fire when it should (or fired when it shouldn't), OR validator rejected output

## Grading workflow

1. For each prompt in `prompts.jsonl`, dispatch a fresh agent (no prior skill context).
2. Record transcript in `results/<id>.md`.
3. Grade against the rubric. Turn every **Fail** into either a one-line gotcha added to `SKILL.md` or a new template in `assets/templates/`.
4. Re-run failures after patching to confirm the fix.
