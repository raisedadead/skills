#!/usr/bin/env python3
"""Validate Google Chat CardsV2 JSON against schema constraints.

Reads JSON from stdin or --input file. Detects format
(card | message | addon-response) and walks the tree, reporting
constraint violations with JSON-pointer paths.

Exit codes: 0 = valid, 1 = errors, 2 = bad invocation.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from typing import Any, Iterable

CARD_ID_RE = re.compile(r"^[a-zA-Z0-9-]{1,64}$")
NAME_RE = re.compile(r"^[a-zA-Z0-9_]+$")

WIDGET_KEYS = {
    "textParagraph", "image", "decoratedText", "buttonList", "textInput",
    "selectionInput", "dateTimePicker", "divider", "grid", "columns",
    "carousel", "chipList",
}

SELECTION_TYPES = {"CHECK_BOX", "RADIO_BUTTON", "SWITCH", "DROPDOWN", "MULTI_SELECT"}
DTP_TYPES = {"DATE_AND_TIME", "DATE_ONLY", "TIME_ONLY"}
TEXT_INPUT_TYPES = {"SINGLE_LINE", "MULTIPLE_LINE"}
BUTTON_TYPES = {"OUTLINED", "FILLED", "FILLED_TONAL", "BORDERLESS"}
IMAGE_TYPES = {"SQUARE", "CIRCLE"}
TEXT_SYNTAX = {"TEXT_SYNTAX_UNSPECIFIED", "HTML", "MARKDOWN"}
HORIZ_ALIGN = {"HORIZONTAL_ALIGNMENT_UNSPECIFIED", "START", "CENTER", "END"}
VERT_ALIGN = {"CENTER", "TOP", "BOTTOM"}
HORIZ_SIZE_STYLE = {"HORIZONTAL_SIZE_STYLE_UNSPECIFIED", "FILL_AVAILABLE_SPACE", "FILL_MINIMUM_SPACE"}
LOAD_INDICATORS = {"SPINNER", "NONE"}
INTERACTIONS = {"INTERACTION_UNSPECIFIED", "OPEN_DIALOG"}
DIVIDER_STYLES = {"DIVIDER_STYLE_UNSPECIFIED", "SOLID_DIVIDER", "NO_DIVIDER"}
ICON_COLORS = set()  # free-form RGB; not validated as enum
VALIDATION_INPUT_TYPES = {"INPUT_TYPE_UNSPECIFIED", "TEXT", "INTEGER", "FLOAT", "EMAIL", "EMOJI_PICKER"}


class Errors:
    def __init__(self) -> None:
        self.items: list[tuple[str, str]] = []

    def add(self, path: str, msg: str) -> None:
        self.items.append((path, msg))

    def __bool__(self) -> bool:
        return bool(self.items)


def detect_format(obj: Any) -> str:
    """Identify input shape: card | message | addon-response."""
    if not isinstance(obj, dict):
        return "unknown"
    if "cardsV2" in obj:
        return "message"
    if "action" in obj and isinstance(obj.get("action"), dict) and "navigations" in obj["action"]:
        return "addon-response"
    if "header" in obj or "sections" in obj or "fixedFooter" in obj:
        return "card"
    return "unknown"


def get_card(obj: Any, fmt: str) -> tuple[Any, str]:
    """Return (card_object, json_pointer_to_card)."""
    if fmt == "card":
        return obj, ""
    if fmt == "message":
        cards = obj.get("cardsV2", [])
        if not isinstance(cards, list) or not cards:
            return None, "/cardsV2"
        return cards[0].get("card"), "/cardsV2/0/card"
    return obj, ""


def validate_message_envelope(obj: dict, errs: Errors) -> None:
    cards = obj.get("cardsV2")
    if not isinstance(cards, list):
        errs.add("/cardsV2", "must be array")
        return
    if not cards:
        errs.add("/cardsV2", "must contain at least one card")
        return
    for i, entry in enumerate(cards):
        base = f"/cardsV2/{i}"
        if not isinstance(entry, dict):
            errs.add(base, "must be object")
            continue
        cid = entry.get("cardId")
        if not isinstance(cid, str) or not CARD_ID_RE.match(cid):
            errs.add(f"{base}/cardId", "required, 1-64 chars, [a-zA-Z0-9-] only")
        if "card" not in entry or not isinstance(entry["card"], dict):
            errs.add(f"{base}/card", "required, must be object")


def validate_card(card: dict, base: str, errs: Errors) -> int:
    """Validate a card object. Returns total widget count."""
    if not isinstance(card, dict):
        errs.add(base, "must be object")
        return 0

    if "header" in card:
        validate_header(card["header"], f"{base}/header", errs)

    sds = card.get("sectionDividerStyle")
    if sds is not None and sds not in DIVIDER_STYLES:
        errs.add(f"{base}/sectionDividerStyle", f"invalid; expected one of {sorted(DIVIDER_STYLES)}")

    total_widgets = 0
    sections = card.get("sections")
    if sections is not None:
        if not isinstance(sections, list):
            errs.add(f"{base}/sections", "must be array")
        else:
            for i, sec in enumerate(sections):
                total_widgets += validate_section(sec, f"{base}/sections/{i}", errs)

    if total_widgets > 100:
        errs.add(base, f"total widgets={total_widgets} exceeds 100; trailing sections will be ignored")

    if "fixedFooter" in card:
        validate_fixed_footer(card["fixedFooter"], f"{base}/fixedFooter", errs)

    if "name" in card:
        n = card["name"]
        if not isinstance(n, str) or not n:
            errs.add(f"{base}/name", "must be non-empty string")

    return total_widgets


def validate_header(h: Any, base: str, errs: Errors) -> None:
    if not isinstance(h, dict):
        errs.add(base, "must be object")
        return
    if not isinstance(h.get("title"), str) or not h["title"]:
        errs.add(f"{base}/title", "required, non-empty string")
    if "imageUrl" in h:
        check_https(h["imageUrl"], f"{base}/imageUrl", errs)
    if "imageType" in h and h["imageType"] not in IMAGE_TYPES:
        errs.add(f"{base}/imageType", f"invalid; expected one of {sorted(IMAGE_TYPES)}")


def validate_section(sec: Any, base: str, errs: Errors) -> int:
    if not isinstance(sec, dict):
        errs.add(base, "must be object")
        return 0
    widgets = sec.get("widgets")
    if not isinstance(widgets, list) or not widgets:
        errs.add(f"{base}/widgets", "required, non-empty array")
        return 0
    if "collapsible" in sec and not isinstance(sec["collapsible"], bool):
        errs.add(f"{base}/collapsible", "must be boolean")
    if "uncollapsibleWidgetsCount" in sec and not isinstance(sec["uncollapsibleWidgetsCount"], int):
        errs.add(f"{base}/uncollapsibleWidgetsCount", "must be integer")
    for i, w in enumerate(widgets):
        validate_widget(w, f"{base}/widgets/{i}", errs)
    return len(widgets)


def validate_widget(w: Any, base: str, errs: Errors) -> None:
    if not isinstance(w, dict):
        errs.add(base, "must be object")
        return
    keys = [k for k in w.keys() if k in WIDGET_KEYS]
    if not keys:
        errs.add(base, f"missing widget type; expected one of {sorted(WIDGET_KEYS)}")
        return
    if len(keys) > 1:
        errs.add(base, f"only one widget type per object; found {keys}")
        return
    wtype = keys[0]
    body = w[wtype]
    handler = WIDGET_HANDLERS.get(wtype)
    if handler:
        handler(body, f"{base}/{wtype}", errs)


def validate_text_paragraph(t: Any, base: str, errs: Errors) -> None:
    if not isinstance(t, dict):
        errs.add(base, "must be object")
        return
    if not isinstance(t.get("text"), str) or not t["text"]:
        errs.add(f"{base}/text", "required, non-empty string")
    if "maxLines" in t and not isinstance(t["maxLines"], int):
        errs.add(f"{base}/maxLines", "must be integer")
    if "textSyntax" in t and t["textSyntax"] not in TEXT_SYNTAX:
        errs.add(f"{base}/textSyntax", f"invalid; expected one of {sorted(TEXT_SYNTAX)}")


def validate_image(img: Any, base: str, errs: Errors) -> None:
    if not isinstance(img, dict):
        errs.add(base, "must be object")
        return
    if "imageUrl" not in img:
        errs.add(f"{base}/imageUrl", "required")
    else:
        check_https(img["imageUrl"], f"{base}/imageUrl", errs)
    if "onClick" in img:
        validate_on_click(img["onClick"], f"{base}/onClick", errs)


def validate_decorated_text(dt: Any, base: str, errs: Errors) -> None:
    if not isinstance(dt, dict):
        errs.add(base, "must be object")
        return
    if not isinstance(dt.get("text"), str) or not dt["text"]:
        errs.add(f"{base}/text", "required, non-empty string")
    for icon_key in ("startIcon", "endIcon"):
        if icon_key in dt:
            validate_icon(dt[icon_key], f"{base}/{icon_key}", errs)
    controls = [k for k in ("button", "switchControl", "endIcon") if k in dt]
    if len(controls) > 1:
        errs.add(base, f"only one of button/switchControl/endIcon allowed; found {controls}")
    if "button" in dt:
        validate_button(dt["button"], f"{base}/button", errs)
    if "onClick" in dt:
        validate_on_click(dt["onClick"], f"{base}/onClick", errs)


def validate_button_list(bl: Any, base: str, errs: Errors) -> None:
    if not isinstance(bl, dict):
        errs.add(base, "must be object")
        return
    buttons = bl.get("buttons")
    if not isinstance(buttons, list) or not buttons:
        errs.add(f"{base}/buttons", "required, non-empty array")
        return
    for i, b in enumerate(buttons):
        validate_button(b, f"{base}/buttons/{i}", errs)


def validate_button(b: Any, base: str, errs: Errors) -> None:
    if not isinstance(b, dict):
        errs.add(base, "must be object")
        return
    if "text" not in b and "icon" not in b:
        errs.add(base, "requires text or icon")
    if "icon" in b:
        validate_icon(b["icon"], f"{base}/icon", errs)
    if "onClick" not in b:
        errs.add(f"{base}/onClick", "required")
    else:
        validate_on_click(b["onClick"], f"{base}/onClick", errs)
    if "type" in b and b["type"] not in BUTTON_TYPES:
        errs.add(f"{base}/type", f"invalid; expected one of {sorted(BUTTON_TYPES)}")
    if "color" in b:
        validate_color(b["color"], f"{base}/color", errs)


def validate_text_input(ti: Any, base: str, errs: Errors) -> None:
    if not isinstance(ti, dict):
        errs.add(base, "must be object")
        return
    if not isinstance(ti.get("name"), str) or not ti["name"]:
        errs.add(f"{base}/name", "required, non-empty string")
    if "label" not in ti and "hintText" not in ti:
        errs.add(base, "requires label or hintText")
    if "type" in ti and ti["type"] not in TEXT_INPUT_TYPES:
        errs.add(f"{base}/type", f"invalid; expected one of {sorted(TEXT_INPUT_TYPES)}")
    if "initialSuggestions" in ti and ti.get("type") == "MULTIPLE_LINE":
        errs.add(f"{base}/type", "initialSuggestions forces SINGLE_LINE")
    if "validation" in ti:
        v = ti["validation"]
        if isinstance(v, dict):
            it = v.get("inputType")
            if it is not None and it not in VALIDATION_INPUT_TYPES:
                errs.add(f"{base}/validation/inputType", f"invalid; expected one of {sorted(VALIDATION_INPUT_TYPES)}")


def validate_selection_input(si: Any, base: str, errs: Errors) -> None:
    if not isinstance(si, dict):
        errs.add(base, "must be object")
        return
    if not isinstance(si.get("name"), str) or not si["name"]:
        errs.add(f"{base}/name", "required, non-empty string")
    t = si.get("type")
    if t not in SELECTION_TYPES:
        errs.add(f"{base}/type", f"required; one of {sorted(SELECTION_TYPES)}")
    items = si.get("items")
    has_dynamic = any(k in si for k in ("externalDataSource", "platformDataSource"))
    if not has_dynamic:
        if not isinstance(items, list) or not items:
            errs.add(f"{base}/items", "required (unless using externalDataSource/platformDataSource)")
        else:
            for i, it in enumerate(items):
                if not isinstance(it, dict):
                    errs.add(f"{base}/items/{i}", "must be object")
                    continue
                if "value" not in it:
                    errs.add(f"{base}/items/{i}/value", "required")


def validate_date_time_picker(d: Any, base: str, errs: Errors) -> None:
    if not isinstance(d, dict):
        errs.add(base, "must be object")
        return
    if not isinstance(d.get("name"), str) or not d["name"]:
        errs.add(f"{base}/name", "required, non-empty string")
    if d.get("type") not in DTP_TYPES:
        errs.add(f"{base}/type", f"required; one of {sorted(DTP_TYPES)}")


def validate_divider(d: Any, base: str, errs: Errors) -> None:
    if not isinstance(d, dict):
        errs.add(base, "must be object (use {})")


def validate_grid(g: Any, base: str, errs: Errors) -> None:
    if not isinstance(g, dict):
        errs.add(base, "must be object")
        return
    items = g.get("items")
    if not isinstance(items, list) or not items:
        errs.add(f"{base}/items", "required, non-empty array")
    if "columnCount" in g and not isinstance(g["columnCount"], int):
        errs.add(f"{base}/columnCount", "must be integer")


def validate_columns(c: Any, base: str, errs: Errors) -> None:
    if not isinstance(c, dict):
        errs.add(base, "must be object")
        return
    cols = c.get("columnItems")
    if not isinstance(cols, list) or not cols:
        errs.add(f"{base}/columnItems", "required, non-empty array")
        return
    if len(cols) > 2:
        errs.add(f"{base}/columnItems", f"max 2 columns; found {len(cols)}")
    for i, col in enumerate(cols):
        if not isinstance(col, dict):
            errs.add(f"{base}/columnItems/{i}", "must be object")
            continue
        if "horizontalAlignment" in col and col["horizontalAlignment"] not in HORIZ_ALIGN:
            errs.add(f"{base}/columnItems/{i}/horizontalAlignment", f"invalid; expected one of {sorted(HORIZ_ALIGN)}")
        if "verticalAlignment" in col and col["verticalAlignment"] not in VERT_ALIGN:
            errs.add(f"{base}/columnItems/{i}/verticalAlignment", f"invalid; expected one of {sorted(VERT_ALIGN)}")
        if "horizontalSizeStyle" in col and col["horizontalSizeStyle"] not in HORIZ_SIZE_STYLE:
            errs.add(f"{base}/columnItems/{i}/horizontalSizeStyle", f"invalid; expected one of {sorted(HORIZ_SIZE_STYLE)}")
        ws = col.get("widgets")
        if isinstance(ws, list):
            for j, w in enumerate(ws):
                validate_widget(w, f"{base}/columnItems/{i}/widgets/{j}", errs)


def validate_carousel(c: Any, base: str, errs: Errors) -> None:
    if not isinstance(c, dict):
        errs.add(base, "must be object")
        return
    cards = c.get("carouselCards")
    if not isinstance(cards, list) or not cards:
        errs.add(f"{base}/carouselCards", "required, non-empty array")


def validate_chip_list(c: Any, base: str, errs: Errors) -> None:
    if not isinstance(c, dict):
        errs.add(base, "must be object")
        return
    chips = c.get("chips")
    if not isinstance(chips, list) or not chips:
        errs.add(f"{base}/chips", "required, non-empty array")


WIDGET_HANDLERS = {
    "textParagraph": validate_text_paragraph,
    "image": validate_image,
    "decoratedText": validate_decorated_text,
    "buttonList": validate_button_list,
    "textInput": validate_text_input,
    "selectionInput": validate_selection_input,
    "dateTimePicker": validate_date_time_picker,
    "divider": validate_divider,
    "grid": validate_grid,
    "columns": validate_columns,
    "carousel": validate_carousel,
    "chipList": validate_chip_list,
}


def validate_icon(icon: Any, base: str, errs: Errors) -> None:
    if not isinstance(icon, dict):
        errs.add(base, "must be object")
        return
    sources = [k for k in ("knownIcon", "iconUrl", "materialIcon") if k in icon]
    if not sources:
        errs.add(base, "requires knownIcon, iconUrl, or materialIcon")
    elif len(sources) > 1:
        errs.add(base, f"only one icon source allowed; found {sources}")
    if "iconUrl" in icon:
        check_https(icon["iconUrl"], f"{base}/iconUrl", errs)
    if "imageType" in icon and icon["imageType"] not in IMAGE_TYPES:
        errs.add(f"{base}/imageType", f"invalid; expected one of {sorted(IMAGE_TYPES)}")


def validate_on_click(oc: Any, base: str, errs: Errors) -> None:
    if not isinstance(oc, dict):
        errs.add(base, "must be object")
        return
    actions = [k for k in ("action", "openLink", "openDynamicLinkAction", "card", "overflowMenu") if k in oc]
    if not actions:
        errs.add(base, "requires action, openLink, openDynamicLinkAction, card, or overflowMenu")
    if "openLink" in oc:
        ol = oc["openLink"]
        if not isinstance(ol, dict) or not isinstance(ol.get("url"), str):
            errs.add(f"{base}/openLink/url", "required string")
        else:
            check_https(ol["url"], f"{base}/openLink/url", errs, allow_http=True)
    if "action" in oc:
        a = oc["action"]
        if isinstance(a, dict):
            if not isinstance(a.get("function"), str) or not a["function"]:
                errs.add(f"{base}/action/function", "required, non-empty string")
            if "loadIndicator" in a and a["loadIndicator"] not in LOAD_INDICATORS:
                errs.add(f"{base}/action/loadIndicator", f"invalid; expected one of {sorted(LOAD_INDICATORS)}")
            if "interaction" in a and a["interaction"] not in INTERACTIONS:
                errs.add(f"{base}/action/interaction", f"invalid; expected one of {sorted(INTERACTIONS)}")


def validate_fixed_footer(f: Any, base: str, errs: Errors) -> None:
    if not isinstance(f, dict):
        errs.add(base, "must be object")
        return
    primary = f.get("primaryButton")
    secondary = f.get("secondaryButton")
    if primary is not None:
        validate_button(primary, f"{base}/primaryButton", errs)
    if secondary is not None:
        validate_button(secondary, f"{base}/secondaryButton", errs)
    if primary is None and secondary is None:
        errs.add(base, "requires primaryButton or secondaryButton")


def check_https(url: Any, base: str, errs: Errors, allow_http: bool = False) -> None:
    if not isinstance(url, str):
        errs.add(base, "must be string")
        return
    if allow_http and url.startswith("http://"):
        return
    if not url.startswith("https://"):
        errs.add(base, f"must be HTTPS URL; got {url[:60]!r}")


def validate_color(c: Any, base: str, errs: Errors) -> None:
    if not isinstance(c, dict):
        errs.add(base, "must be object with red/green/blue/alpha 0..1")
        return
    for k in ("red", "green", "blue"):
        v = c.get(k, 0)
        if not isinstance(v, (int, float)) or not (0 <= v <= 1):
            errs.add(f"{base}/{k}", "must be number in [0, 1]")


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description="Validate CardsV2 JSON")
    p.add_argument("--input", "-i", help="Input file (default stdin)")
    p.add_argument("--quiet", "-q", action="store_true", help="Suppress 'OK' on success")
    p.add_argument("path", nargs="?", help="Input file (positional alias for --input)")
    args = p.parse_args(argv)

    src = args.input or args.path
    raw = sys.stdin.read() if not src else open(src, encoding="utf-8").read()
    try:
        obj = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"ERROR: invalid JSON: {e}", file=sys.stderr)
        return 1

    fmt = detect_format(obj)
    errs = Errors()

    if fmt == "unknown":
        print("ERROR: cannot detect format. Expected card, message envelope (cardsV2), or add-on response.", file=sys.stderr)
        return 1

    if fmt == "message":
        validate_message_envelope(obj, errs)
        card, base = get_card(obj, fmt)
        if card is not None:
            validate_card(card, base, errs)
    else:
        validate_card(obj, "", errs)

    if errs:
        print(f"INVALID ({fmt}): {len(errs.items)} error(s)", file=sys.stderr)
        for path, msg in errs.items:
            print(f"  {path or '/'}: {msg}", file=sys.stderr)
        return 1

    if not args.quiet:
        print(f"OK ({fmt})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
