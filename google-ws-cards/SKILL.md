---
name: google-ws-cards
description: >
  Use this skill to generate, modify, or validate Google Chat / Workspace
  add-on card JSON — the payloads that pair with the Card Builder at
  addons.gsuite.google.com/uikit/builder and the Chat REST API `cardsV2`
  field. Trigger any time the user asks for an interactive message,
  dialog, notification card, approval card, form card, dashboard card,
  app message, add-on home card, peek card, or bot-posted rich card for
  Google Chat, Gmail, Calendar, Drive, Docs, Sheets, or Slides — even if
  they don't name "CardsV2", "UIkit", "Card Builder", or "Google Chat"
  directly. Also applies when the user pastes existing card JSON and
  asks to fix, extend, or validate it. Example triggers: "build a Chat
  bot card that…", "make a dialog to collect…", "send a rich message
  with buttons to Google Chat", "add-on card for a Gmail contextual
  trigger", "validate this Card Builder JSON", "why does my card render
  blank in UIkit Builder", "add a decorated row with an icon", "turn
  this JSON into the Chat message envelope".
license: MIT
metadata:
  author: mrugesh
  version: "0.1.0"
compatibility: Requires Python 3.9+ (stdlib only). Network access not required at runtime.
allowed-tools: Bash(python3:*) Read Write Edit
---

# google-ws-cards

Generate spec-compliant Google Chat / Workspace add-on **CardsV2** JSON, validated locally and ready to paste into the [UIkit Builder](https://addons.gsuite.google.com/uikit/builder).

## When to use

Trigger this skill when the user asks for:

- A Google Chat card, app message, or dialog
- A Workspace add-on home / contextual card
- Anything described as "CardsV2", "Chat card JSON", "Card Builder JSON"
- Modifying or validating an existing CardsV2 payload

## Workflow (do this in order)

1. **Pick a starting point.** Look in `assets/templates/` first. Match the user's intent:
   | Intent | Template |
   |---|---|
   | Notify / announce | `announcement.json` |
   | Collect input | `form.json` |
   | Show metrics / status | `dashboard.json` |
   | Approve / reject flow | `approval.json` |
   | Incident / failure alert | `alert.json` |
   | Person / contact card | `profile.json` |
   | Modal dialog with footer | `dialog.json` |
   | Add-on home card | `addon-home.json` |

   If none fits, write **shorthand JSON** and let `scripts/build.py` expand it.

2. **Author the card.** Two paths:

   **Path A — edit a template.** Read it, modify text / labels / URLs, save the result. Stay in CardsV2 form.

   **Path B — write shorthand, expand it.** Use the shorthand DSL (see below). Pipe through `scripts/build.py` to produce a full card.

3. **Validate.** Always run `scripts/validate.py` on the final JSON before handing back to the user. Do not skip this — it catches the failures the UIkit Builder would silently swallow (HTTPS-only URLs, missing `name` on form widgets, max 100 widgets per card, max 2 columns, missing `cardId`, etc.).

4. **Wrap for the target.** The UIkit Builder expects a bare **card** object. The Chat REST API expects a **message** envelope. Workspace add-on responses use a third shape. Pick one:

   ```bash
   # Bare card (default — paste straight into UIkit Builder)
   python3 scripts/build.py -i spec.json --pretty > card.json

   # Chat message envelope (cardsV2 array)
   python3 scripts/build.py -i spec.json -f message --card-id my-card --pretty

   # Add-on response (action.navigations[0].pushCard)
   python3 scripts/build.py -i spec.json -f addon --pretty
   ```

5. **Hand back the JSON and the UIkit Builder URL.** Tell the user to paste into <https://addons.gsuite.google.com/uikit/builder>.

## Shorthand DSL (use this — saves tokens, runs validated)

`scripts/build.py` accepts a terse JSON DSL. The script expands and validates in one pass. Use this whenever you'd otherwise hand-write nested `textParagraph` / `buttonList` boilerplate.

| Shorthand                                                                     | Expands to                                 |
| ----------------------------------------------------------------------------- | ------------------------------------------ |
| `{"text": "Hello"}`                                                           | `{"textParagraph": {"text": "Hello"}}`     |
| `{"divider": true}`                                                           | `{"divider": {}}`                          |
| `{"image": "https://x"}`                                                      | `{"image": {"imageUrl": "https://x"}}`     |
| `{"button": {"text": "Go", "url": "https://x"}}`                              | single-button `buttonList` with `openLink` |
| `{"button": {"text": "Go", "fn": "doThing", "params": {"id": "1"}}}`          | single-button `buttonList` with `action`   |
| `{"buttons": [...]}`                                                          | `buttonList` with each entry expanded      |
| `{"decorated": {"text": "X", "topLabel": "Y", "icon": "STAR"}}`               | full `decoratedText`                       |
| `{"chips": [{"text": "Filter", "url": "..."}]}`                               | `chipList`                                 |
| `{"input": {"name": "x", "label": "X"}}`                                      | `textInput`                                |
| `{"select": {"name": "x", "label": "X", "type": "DROPDOWN", "items": [...]}}` | `selectionInput`                           |
| `{"datetime": {"name": "x", "label": "When", "type": "DATE_AND_TIME"}}`       | `dateTimePicker`                           |
| `{"columns": [ {"widgets": [...]}, {"widgets": [...]} ]}`                     | two-column layout                          |
| `{"header": "Title"}`                                                         | `{"header": {"title": "Title"}}`           |
| `{"widgets": [...]}` (top-level, no `sections`)                               | wraps in single section                    |

Icon shorthand inside `decorated` / `button`:

- `"STAR"` → `{"knownIcon": "STAR"}`
- `"check_circle"` → `{"materialIcon": {"name": "check_circle"}}`
- `"https://..."` → `{"iconUrl": "..."}`

### Minimal end-to-end example

Spec the model writes (~20 lines):

```json
{
  "header": "Build #1284 failed",
  "widgets": [
    {
      "decorated": {
        "topLabel": "Service",
        "text": "checkout",
        "icon": "BOOKMARK"
      }
    },
    { "text": "<b>Error</b>: image tag not found" },
    {
      "buttons": [
        { "text": "Logs", "url": "https://example.com/logs", "type": "FILLED" },
        { "text": "Retry", "fn": "retryBuild", "params": { "id": "1284" } }
      ]
    }
  ]
}
```

Pipeline:

```bash
python3 scripts/build.py -i spec.json --pretty > card.json
# build.py runs validate.py automatically; non-zero exit aborts
```

## Gotchas (the validator enforces these — do not violate)

- All `imageUrl`, `iconUrl`, `image.imageUrl`, header `imageUrl` values must use `https://`. No `http://`, no `mailto:`, no `data:` URIs.
- `cardId` (in message envelope) must match `[a-zA-Z0-9-]{1,64}`.
- `header.title` is required if `header` is present.
- Each widget object must contain exactly **one** widget-type key. Mixing `textParagraph` and `image` in one object is invalid.
- `Section.widgets` must be a non-empty array.
- Total widgets across all sections must be ≤ 100. The 101st widget and every section after it are silently dropped by the renderer.
- `Columns.columnItems` ≤ 2.
- `Button` requires `text` or `icon`, plus `onClick`.
- `TextInput` requires `name` and one of `label` / `hintText`. `initialSuggestions` forces `type=SINGLE_LINE`.
- `SelectionInput` requires `name`, `type` (`CHECK_BOX` / `RADIO_BUTTON` / `SWITCH` / `DROPDOWN` / `MULTI_SELECT`), and `items` (unless using a dynamic data source).
- `DateTimePicker.type` ∈ {`DATE_AND_TIME`, `DATE_ONLY`, `TIME_ONLY`}.
- `Action.function` must be a non-empty string. `parameters` items are `{key, value}` (both strings).

## Reference material

Load on demand:

- `references/SCHEMA.md` — full field reference for every widget, every enum, every constraint.
- `references/WIDGETS.md` — copy-paste JSON snippets for every widget type.

## Output contract

When the user asks for a card, your final message must include:

1. The CardsV2 JSON (formatted, in a fenced ```json block).
2. The format used (`card` / `message` / `addon`).
3. The UIkit Builder URL: <https://addons.gsuite.google.com/uikit/builder>.
4. Confirmation that `validate.py` returned `OK`.

Do not ship JSON that has not been through `validate.py`.
