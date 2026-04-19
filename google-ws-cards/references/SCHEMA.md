# CardsV2 schema reference

Authoritative source: <https://developers.google.com/workspace/chat/api/reference/rest/v1/cards>.

This file mirrors the constraints the validator enforces. When the spec evolves, update both this file and `scripts/validate.py`.

## Top-level shapes

### Bare card (UIkit Builder paste target)

```json
{
  "header": { ... },
  "sections": [ ... ],
  "sectionDividerStyle": "SOLID_DIVIDER",
  "fixedFooter": { ... },
  "name": "homeCard",
  "displayStyle": "PEEK",
  "peekCardHeader": { ... },
  "cardActions": [ ... ]
}
```

### Chat message envelope

```json
{
  "cardsV2": [
    { "cardId": "alpha-1", "card": { ...card... } }
  ]
}
```

`cardId` MUST match `^[a-zA-Z0-9-]{1,64}$`.

### Workspace add-on response

```json
{ "action": { "navigations": [ { "pushCard": { ...card... } } ] } }
```

Other navigations: `popCard`, `popToRoot`, `updateCard`, `popToNamedCard`.

## Card

| Field                 | Type            | Notes                                                           |
| --------------------- | --------------- | --------------------------------------------------------------- |
| `header`              | CardHeader      | Optional.                                                       |
| `sections`            | Section[]       | Optional but typical.                                           |
| `sectionDividerStyle` | enum            | `SOLID_DIVIDER` \| `NO_DIVIDER` \| `DIVIDER_STYLE_UNSPECIFIED`. |
| `fixedFooter`         | CardFixedFooter | Dialogs / add-ons.                                              |
| `name`                | string          | Add-on navigation handle.                                       |
| `displayStyle`        | enum            | `PEEK` \| `REPLACE`. Add-ons.                                   |
| `peekCardHeader`      | CardHeader      | Add-ons.                                                        |
| `cardActions`         | CardAction[]    | Add-on toolbar overflow menu.                                   |

**Hard cap: 100 widgets per card** (sum of widgets across all sections). The 101st widget and all subsequent sections are silently ignored.

## CardHeader

| Field          | Required | Notes                           |
| -------------- | -------- | ------------------------------- |
| `title`        | yes      | Non-empty string.               |
| `subtitle`     | no       |                                 |
| `imageUrl`     | no       | HTTPS only.                     |
| `imageAltText` | no       |                                 |
| `imageType`    | no       | `SQUARE` (default) \| `CIRCLE`. |

## Section

| Field                       | Required | Notes                                                                                |
| --------------------------- | -------- | ------------------------------------------------------------------------------------ |
| `widgets`                   | yes      | Non-empty array.                                                                     |
| `header`                    | no       | Supports a tiny HTML subset (`<b>`, `<i>`, `<u>`, `<s>`, `<a>`, `<font>`, `<br>`).   |
| `collapsible`               | no       | boolean.                                                                             |
| `uncollapsibleWidgetsCount` | no       | int. Required only with `collapsible: true` if you want some widgets always visible. |

## Widgets

Each widget object has **exactly one** key from this set:

`textParagraph` · `image` · `decoratedText` · `buttonList` · `textInput` · `selectionInput` · `dateTimePicker` · `divider` · `grid` · `columns` · `carousel` · `chipList`

### TextParagraph

| Field        | Required | Notes                                       |
| ------------ | -------- | ------------------------------------------- |
| `text`       | yes      | HTML or Markdown depending on `textSyntax`. |
| `maxLines`   | no       | Integer; "show more" if exceeded.           |
| `textSyntax` | no       | `HTML` (default) \| `MARKDOWN`.             |

### Image

| Field      | Required | Notes       |
| ---------- | -------- | ----------- |
| `imageUrl` | yes      | HTTPS only. |
| `altText`  | no       |             |
| `onClick`  | no       |             |

### DecoratedText

| Field           | Required | Notes                                                         |
| --------------- | -------- | ------------------------------------------------------------- |
| `text`          | yes      |                                                               |
| `topLabel`      | no       |                                                               |
| `bottomLabel`   | no       |                                                               |
| `wrapText`      | no       | bool. Defaults to single-line truncation.                     |
| `startIcon`     | no       | Icon.                                                         |
| `endIcon`       | no       | Icon. **Mutually exclusive with `button` / `switchControl`.** |
| `button`        | no       | Right-side trailing button.                                   |
| `switchControl` | no       | Right-side switch / checkbox.                                 |
| `onClick`       | no       | Whole-row click.                                              |

### Button

| Field      | Required | Notes                                                               |
| ---------- | -------- | ------------------------------------------------------------------- |
| `text`     | one of   | `text` or `icon` (or both).                                         |
| `icon`     | one of   | Icon.                                                               |
| `onClick`  | yes      |                                                                     |
| `type`     | no       | `OUTLINED` (default) \| `FILLED` \| `FILLED_TONAL` \| `BORDERLESS`. |
| `color`    | no       | `{red, green, blue, alpha}` floats 0..1.                            |
| `disabled` | no       | bool.                                                               |
| `altText`  | no       | Accessibility.                                                      |

### ButtonList

| Field     | Required                        |
| --------- | ------------------------------- |
| `buttons` | yes (non-empty array of Button) |

### TextInput

| Field                | Required | Notes                                                                                                     |
| -------------------- | -------- | --------------------------------------------------------------------------------------------------------- |
| `name`               | yes      | Form key.                                                                                                 |
| `label`              | one of   | `label` or `hintText` required.                                                                           |
| `hintText`           | one of   |                                                                                                           |
| `type`               | no       | `SINGLE_LINE` (default) \| `MULTIPLE_LINE`.                                                               |
| `value`              | no       | Pre-fill.                                                                                                 |
| `placeholder`        | no       |                                                                                                           |
| `onChangeAction`     | no       |                                                                                                           |
| `initialSuggestions` | no       | `{items: [{text}]}`. Forces `SINGLE_LINE`.                                                                |
| `validation`         | no       | `{characterLimit, inputType}`. `inputType` ∈ `TEXT` \| `INTEGER` \| `FLOAT` \| `EMAIL` \| `EMOJI_PICKER`. |

### SelectionInput

| Field                         | Required | Notes                                                                      |
| ----------------------------- | -------- | -------------------------------------------------------------------------- |
| `name`                        | yes      |                                                                            |
| `type`                        | yes      | `CHECK_BOX` \| `RADIO_BUTTON` \| `SWITCH` \| `DROPDOWN` \| `MULTI_SELECT`. |
| `items`                       | yes\*    | Required unless `externalDataSource` or `platformDataSource` set.          |
| `label`                       | no       |                                                                            |
| `onChangeAction`              | no       |                                                                            |
| `multiSelectMaxSelectedItems` | no       | int.                                                                       |
| `multiSelectMinQueryLength`   | no       | int.                                                                       |

`items[*]`: `{ text, value, selected, startIconUri?, bottomText? }`. `value` required.

### DateTimePicker

| Field                | Required | Notes                                          |
| -------------------- | -------- | ---------------------------------------------- |
| `name`               | yes      |                                                |
| `type`               | yes      | `DATE_AND_TIME` \| `DATE_ONLY` \| `TIME_ONLY`. |
| `label`              | no       |                                                |
| `valueMsEpoch`       | no       | Pre-selected timestamp (ms).                   |
| `timezoneOffsetDate` | no       | int (minutes).                                 |
| `onChangeAction`     | no       |                                                |

### Divider

`{"divider": {}}` — empty object literal. Anything else is invalid.

### Grid

| Field         | Required | Notes                                                     |
| ------------- | -------- | --------------------------------------------------------- |
| `items`       | yes      | Non-empty array.                                          |
| `title`       | no       |                                                           |
| `columnCount` | no       | int.                                                      |
| `borderStyle` | no       | `{type: NO_BORDER \| STROKE, strokeColor, cornerRadius}`. |
| `onClick`     | no       |                                                           |

`items[*]`: `{ image: {imageUri, cropStyle?, borderStyle?}, title, subtitle, layout, textAlignment }`.

### Columns

| Field         | Required | Notes              |
| ------------- | -------- | ------------------ |
| `columnItems` | yes      | **Max 2 entries.** |

Each column item:

| Field                 | Notes                                          |
| --------------------- | ---------------------------------------------- |
| `widgets`             | array of widgets                               |
| `horizontalSizeStyle` | `FILL_AVAILABLE_SPACE` \| `FILL_MINIMUM_SPACE` |
| `horizontalAlignment` | `START` \| `CENTER` \| `END`                   |
| `verticalAlignment`   | `CENTER` \| `TOP` \| `BOTTOM`                  |

### Carousel

`{"carousel": {"carouselCards": [ {widgets: [...] }, ... ]}}`

### ChipList

| Field    | Required | Notes                                 |
| -------- | -------- | ------------------------------------- |
| `chips`  | yes      | Non-empty array.                      |
| `layout` | no       | `WRAPPED` \| `HORIZONTAL_SCROLLABLE`. |

`chips[*]`: `{ label, icon?, onClick?, disabled?, altText? }`.

## Icon

Pick exactly one source:

| Field          | Notes                                                                                                                                                    |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `knownIcon`    | Built-in (e.g. `STAR`, `EMAIL`, `PHONE`, `MAP_PIN`, `CLOCK`, `INVITE`, `BOOKMARK`, `DESCRIPTION`, `PERSON`, `EVENT_SEAT`, `TRAIN`, `AIRPLANE`, `HOTEL`). |
| `materialIcon` | `{name: "check_circle", fill?, weight?, grade?}`. Lowercase Material Symbols name.                                                                       |
| `iconUrl`      | HTTPS URL.                                                                                                                                               |

Optional shared:

- `altText`
- `imageType` — `SQUARE` \| `CIRCLE`.

## OnClick

Exactly one of:

| Field                   | Notes                                                                                     |
| ----------------------- | ----------------------------------------------------------------------------------------- |
| `action`                | `{function, parameters[], loadIndicator, persistValues, interaction, requiredWidgets[]}`. |
| `openLink`              | `{url}`. HTTPS strongly preferred.                                                        |
| `openDynamicLinkAction` | Add-ons only.                                                                             |
| `card`                  | Push card to stack. Add-ons only.                                                         |
| `overflowMenu`          | `{items: [{text, startIcon, onClick, disabled}]}`.                                        |

### Action

| Field                   | Notes                                                                                                         |
| ----------------------- | ------------------------------------------------------------------------------------------------------------- |
| `function`              | Required, non-empty string.                                                                                   |
| `parameters`            | `[{key, value}]` — both strings.                                                                              |
| `loadIndicator`         | `SPINNER` (default) \| `NONE`.                                                                                |
| `persistValues`         | bool.                                                                                                         |
| `interaction`           | `INTERACTION_UNSPECIFIED` \| `OPEN_DIALOG`. Set `OPEN_DIALOG` from a Chat-app entry point to launch a dialog. |
| `requiredWidgets`       | string[] of widget `name`s.                                                                                   |
| `allWidgetsAreRequired` | bool.                                                                                                         |

## CardFixedFooter

| Field             | Notes   |
| ----------------- | ------- |
| `primaryButton`   | Button. |
| `secondaryButton` | Button. |

At least one of the two is required.

## Validator behavior

`scripts/validate.py` enforces:

- All HTTPS rules above (header image, widget image, icon URL).
- `cardId` regex.
- Required fields per widget.
- Enum values for every enum-typed field.
- Widget-count cap (warns past 100).
- Single widget-type key per widget object.
- Mutual exclusion between `button`, `switchControl`, `endIcon` on `DecoratedText`.
- `Columns.columnItems` ≤ 2.
- `openLink.url` must be `http://` or `https://` (HTTP allowed only because the renderer auto-upgrades it).

It does NOT enforce:

- `materialIcon.name` against the live Material Symbols catalog (icon may render blank if name is wrong).
- `knownIcon` against the live built-in catalog (limited public list — verify in UIkit Builder).
- `text` HTML tag whitelist (Chat silently strips unsupported tags).
