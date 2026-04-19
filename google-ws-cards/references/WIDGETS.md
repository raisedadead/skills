# Widget snippets

Copy-paste ready CardsV2 widget objects. Each is wrapped as `{"<widgetType>": {...}}` so you can drop straight into a `Section.widgets` array.

## TextParagraph

```json
{
  "textParagraph": {
    "text": "Plain text. Supports a tiny HTML subset: <b>bold</b>, <i>italic</i>, <u>underline</u>, <s>strike</s>, <font color=\"#ff0000\">red</font>, <a href=\"https://example.com\">link</a>, <br>line break.",
    "maxLines": 3
  }
}
```

Markdown variant:

```json
{
  "textParagraph": {
    "text": "**bold** _italic_ [link](https://example.com)",
    "textSyntax": "MARKDOWN"
  }
}
```

## Image

```json
{
  "image": {
    "imageUrl": "https://example.com/banner.png",
    "altText": "Project banner",
    "onClick": { "openLink": { "url": "https://example.com/project" } }
  }
}
```

## DecoratedText

Top-label + value + icon:

```json
{
  "decoratedText": {
    "topLabel": "Owner",
    "text": "Alice Chen",
    "bottomLabel": "Engineering",
    "startIcon": { "knownIcon": "PERSON" }
  }
}
```

With trailing button:

```json
{
  "decoratedText": {
    "text": "Notifications",
    "startIcon": { "knownIcon": "EMAIL" },
    "button": {
      "text": "Settings",
      "onClick": { "openLink": { "url": "https://example.com/settings" } }
    }
  }
}
```

With switch:

```json
{
  "decoratedText": {
    "text": "Email me digests",
    "switchControl": {
      "name": "digests",
      "value": "on",
      "selected": true,
      "controlType": "SWITCH"
    }
  }
}
```

## Button + ButtonList

```json
{
  "buttonList": {
    "buttons": [
      {
        "text": "Open",
        "type": "FILLED",
        "onClick": { "openLink": { "url": "https://example.com" } }
      },
      {
        "text": "Submit",
        "icon": { "knownIcon": "STAR" },
        "onClick": {
          "action": {
            "function": "submit",
            "parameters": [{ "key": "id", "value": "42" }],
            "loadIndicator": "SPINNER"
          }
        }
      },
      {
        "text": "Disabled",
        "disabled": true,
        "type": "OUTLINED",
        "onClick": { "action": { "function": "noop" } }
      }
    ]
  }
}
```

## TextInput

```json
{
  "textInput": {
    "name": "email",
    "label": "Email",
    "hintText": "you@example.com",
    "type": "SINGLE_LINE",
    "validation": { "inputType": "EMAIL" }
  }
}
```

Multi-line with autosuggest:

```json
{
  "textInput": {
    "name": "tags",
    "label": "Tags",
    "type": "SINGLE_LINE",
    "initialSuggestions": {
      "items": [{ "text": "bug" }, { "text": "feature" }, { "text": "chore" }]
    }
  }
}
```

## SelectionInput

Dropdown:

```json
{
  "selectionInput": {
    "name": "priority",
    "label": "Priority",
    "type": "DROPDOWN",
    "items": [
      { "text": "P0", "value": "p0", "selected": false },
      { "text": "P1", "value": "p1", "selected": true },
      { "text": "P2", "value": "p2", "selected": false }
    ]
  }
}
```

Radio:

```json
{
  "selectionInput": {
    "name": "env",
    "label": "Environment",
    "type": "RADIO_BUTTON",
    "items": [
      { "text": "dev", "value": "dev", "selected": true },
      { "text": "stg", "value": "stg", "selected": false },
      { "text": "prod", "value": "prod", "selected": false }
    ]
  }
}
```

Multi-select:

```json
{
  "selectionInput": {
    "name": "labels",
    "label": "Labels",
    "type": "MULTI_SELECT",
    "multiSelectMaxSelectedItems": 5,
    "items": [
      { "text": "frontend", "value": "fe", "selected": false },
      { "text": "backend", "value": "be", "selected": false },
      { "text": "infra", "value": "infra", "selected": false }
    ]
  }
}
```

## DateTimePicker

```json
{
  "dateTimePicker": {
    "name": "due",
    "label": "Due",
    "type": "DATE_AND_TIME"
  }
}
```

## Divider

```json
{ "divider": {} }
```

## Grid

```json
{
  "grid": {
    "title": "Top services",
    "columnCount": 2,
    "items": [
      {
        "title": "checkout",
        "subtitle": "healthy",
        "image": {
          "imageUri": "https://example.com/checkout.png",
          "cropStyle": { "type": "SQUARE" }
        }
      },
      {
        "title": "search",
        "subtitle": "healthy",
        "image": {
          "imageUri": "https://example.com/search.png",
          "cropStyle": { "type": "SQUARE" }
        }
      }
    ],
    "borderStyle": { "type": "STROKE", "cornerRadius": 8 }
  }
}
```

## Columns

```json
{
  "columns": {
    "columnItems": [
      {
        "horizontalSizeStyle": "FILL_AVAILABLE_SPACE",
        "horizontalAlignment": "START",
        "verticalAlignment": "CENTER",
        "widgets": [{ "textParagraph": { "text": "<b>Left</b>" } }]
      },
      {
        "horizontalSizeStyle": "FILL_AVAILABLE_SPACE",
        "horizontalAlignment": "END",
        "verticalAlignment": "CENTER",
        "widgets": [{ "textParagraph": { "text": "Right" } }]
      }
    ]
  }
}
```

## Carousel

```json
{
  "carousel": {
    "carouselCards": [
      { "widgets": [{ "textParagraph": { "text": "Slide 1" } }] },
      { "widgets": [{ "textParagraph": { "text": "Slide 2" } }] }
    ]
  }
}
```

## ChipList

```json
{
  "chipList": {
    "chips": [
      {
        "label": "Open in browser",
        "icon": { "knownIcon": "BOOKMARK" },
        "onClick": { "openLink": { "url": "https://example.com" } }
      },
      {
        "label": "Refresh",
        "onClick": { "action": { "function": "refresh" } }
      }
    ]
  }
}
```

## CardFixedFooter (dialogs)

```json
{
  "fixedFooter": {
    "primaryButton": {
      "text": "Save",
      "type": "FILLED",
      "onClick": { "action": { "function": "save" } }
    },
    "secondaryButton": {
      "text": "Cancel",
      "onClick": { "action": { "function": "cancel" } }
    }
  }
}
```
