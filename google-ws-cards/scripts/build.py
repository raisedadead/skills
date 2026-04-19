#!/usr/bin/env python3
"""Expand CardsV2 shorthand JSON into a fully spec-compliant card.

Reads shorthand JSON from stdin or --input. Applies the expansions
listed below, then runs validate.py and emits the result.

Shorthand expansions
--------------------
- {"text": "..."}                  -> textParagraph
- {"divider": true}                -> {"divider": {}}
- {"image": "https://..."}         -> {"image": {"imageUrl": "..."}}
- {"button": {text, url}}          -> single-item buttonList with openLink
- {"button": {text, fn, params}}   -> single-item buttonList with action
- {"buttons": [ {text, url}, ... ]}-> buttonList with each entry expanded
- {"decorated": {text, label, icon, url?}} -> decoratedText
- {"chips": [{text, url}, ...]}    -> chipList
- {"input": {name, label, type?}}  -> textInput
- {"select": {name, label, type, items}} -> selectionInput

Output formats
--------------
- card    (default): emit just the card object (paste into UIkit Builder)
- message:           wrap in {"cardsV2":[{"cardId":..., "card":{...}}]}
- addon:             wrap in {"action":{"navigations":[{"pushCard":{...}}]}}

Use --no-validate to skip the post-build validation pass.
"""
from __future__ import annotations

import argparse
import json
import sys
import uuid
from pathlib import Path
from typing import Any

# Allow importing validate.py from the same directory
sys.path.insert(0, str(Path(__file__).resolve().parent))
import validate  # noqa: E402


def expand_widget(w: Any) -> dict:
    """Convert a shorthand widget into a CardsV2 widget object."""
    if not isinstance(w, dict):
        raise ValueError(f"widget must be object, got {type(w).__name__}")

    # Already a real widget (its value must be the proper object form)? Pass through.
    real_keys = [k for k in validate.WIDGET_KEYS if k in w]
    if real_keys and len(real_keys) == 1 and isinstance(w[real_keys[0]], dict):
        return w

    if "text" in w and len(w) <= 3 and "label" not in w and "icon" not in w:
        out: dict[str, Any] = {"text": w["text"]}
        if "maxLines" in w:
            out["maxLines"] = w["maxLines"]
        if "syntax" in w:
            out["textSyntax"] = w["syntax"]
        return {"textParagraph": out}

    if w.get("divider") is True or w == {"divider": {}}:
        return {"divider": {}}

    if "image" in w:
        v = w["image"]
        if isinstance(v, str):
            return {"image": {"imageUrl": v, **({"altText": w["alt"]} if "alt" in w else {})}}
        return {"image": v}

    if "button" in w:
        return {"buttonList": {"buttons": [expand_button(w["button"])]}}

    if "buttons" in w:
        return {"buttonList": {"buttons": [expand_button(b) for b in w["buttons"]]}}

    if "decorated" in w:
        return {"decoratedText": expand_decorated(w["decorated"])}

    if "chips" in w:
        return {"chipList": {"chips": [expand_chip(c) for c in w["chips"]]}}

    if "input" in w:
        return {"textInput": expand_text_input(w["input"])}

    if "select" in w:
        return {"selectionInput": expand_selection(w["select"])}

    if "datetime" in w:
        return {"dateTimePicker": expand_datetime(w["datetime"])}

    if "grid" in w:
        return {"grid": w["grid"]}

    if "columns" in w:
        cols = w["columns"]
        if isinstance(cols, list):
            return {"columns": {"columnItems": [expand_column(c) for c in cols]}}
        return {"columns": cols}

    raise ValueError(f"unknown shorthand keys: {sorted(w.keys())}")


def expand_button(b: Any) -> dict:
    if not isinstance(b, dict):
        raise ValueError("button must be object")
    out: dict[str, Any] = {}
    if "text" in b:
        out["text"] = b["text"]
    if "icon" in b:
        out["icon"] = expand_icon(b["icon"])
    if "type" in b:
        out["type"] = b["type"]
    if "color" in b:
        out["color"] = b["color"]
    if "disabled" in b:
        out["disabled"] = b["disabled"]
    if "altText" in b:
        out["altText"] = b["altText"]
    out["onClick"] = expand_on_click(b)
    return out


def expand_on_click(b: dict) -> dict:
    if "url" in b:
        return {"openLink": {"url": b["url"]}}
    if "fn" in b or "function" in b:
        action: dict[str, Any] = {"function": b.get("fn") or b["function"]}
        if "params" in b:
            action["parameters"] = [{"key": k, "value": str(v)} for k, v in b["params"].items()]
        elif "parameters" in b:
            action["parameters"] = b["parameters"]
        if "loadIndicator" in b:
            action["loadIndicator"] = b["loadIndicator"]
        if "interaction" in b:
            action["interaction"] = b["interaction"]
        return {"action": action}
    if "onClick" in b:
        return b["onClick"]
    raise ValueError("button requires url, fn/function, or onClick")


def expand_icon(icon: Any) -> dict:
    if isinstance(icon, str):
        # Heuristic: URL -> iconUrl; uppercase token -> knownIcon; else materialIcon name
        if icon.startswith("http"):
            return {"iconUrl": icon}
        if icon.isupper() or "_" in icon and icon.replace("_", "").isupper():
            return {"knownIcon": icon}
        return {"materialIcon": {"name": icon}}
    if isinstance(icon, dict):
        return icon
    raise ValueError("icon must be str or object")


def expand_decorated(d: dict) -> dict:
    out: dict[str, Any] = {"text": d["text"]}
    if "topLabel" in d:
        out["topLabel"] = d["topLabel"]
    if "bottomLabel" in d:
        out["bottomLabel"] = d["bottomLabel"]
    if "wrapText" in d:
        out["wrapText"] = d["wrapText"]
    if "startIcon" in d:
        out["startIcon"] = expand_icon(d["startIcon"])
    if "endIcon" in d:
        out["endIcon"] = expand_icon(d["endIcon"])
    if "icon" in d:  # convenience: maps to startIcon
        out["startIcon"] = expand_icon(d["icon"])
    if "url" in d:
        out["onClick"] = {"openLink": {"url": d["url"]}}
    elif "fn" in d:
        out["onClick"] = expand_on_click(d)
    if "button" in d:
        out["button"] = expand_button(d["button"])
    if "switch" in d:
        out["switchControl"] = d["switch"]
    return out


def expand_chip(c: dict) -> dict:
    chip: dict[str, Any] = {}
    label = chip.setdefault("label", c.get("text") or c.get("label", ""))
    if not label:
        raise ValueError("chip requires text/label")
    if "icon" in c:
        chip["icon"] = expand_icon(c["icon"])
    if "url" in c or "fn" in c or "onClick" in c:
        chip["onClick"] = expand_on_click(c)
    if "disabled" in c:
        chip["disabled"] = c["disabled"]
    return chip


def expand_text_input(t: dict) -> dict:
    out = {"name": t["name"]}
    for k in ("label", "hintText", "value", "placeholder", "type"):
        if k in t:
            out[k] = t[k]
    if "suggestions" in t:
        out["initialSuggestions"] = {"items": [{"text": s} for s in t["suggestions"]]}
    if "validation" in t:
        out["validation"] = t["validation"]
    return out


def expand_selection(s: dict) -> dict:
    out = {"name": s["name"], "type": s["type"]}
    if "label" in s:
        out["label"] = s["label"]
    items = s.get("items", [])
    out["items"] = [
        {"text": i.get("text", i["value"]), "value": i["value"], "selected": i.get("selected", False)}
        if isinstance(i, dict) else
        {"text": str(i), "value": str(i), "selected": False}
        for i in items
    ]
    if "onChangeAction" in s:
        out["onChangeAction"] = s["onChangeAction"]
    return out


def expand_datetime(d: dict) -> dict:
    out = {"name": d["name"], "type": d.get("type", "DATE_AND_TIME")}
    if "label" in d:
        out["label"] = d["label"]
    if "valueMsEpoch" in d:
        out["valueMsEpoch"] = d["valueMsEpoch"]
    return out


def expand_column(col: dict) -> dict:
    out: dict[str, Any] = {}
    for k in ("horizontalSizeStyle", "horizontalAlignment", "verticalAlignment"):
        if k in col:
            out[k] = col[k]
    out["widgets"] = [expand_widget(w) for w in col.get("widgets", [])]
    return out


def expand_section(sec: Any) -> dict:
    if not isinstance(sec, dict):
        raise ValueError("section must be object")
    if "widgets" not in sec:
        raise ValueError("section requires widgets")
    out: dict[str, Any] = {"widgets": [expand_widget(w) for w in sec["widgets"]]}
    for k in ("header", "collapsible", "uncollapsibleWidgetsCount"):
        if k in sec:
            out[k] = sec[k]
    return out


def expand_card(spec: dict) -> dict:
    """Expand a shorthand card spec into full CardsV2 card."""
    card: dict[str, Any] = {}
    if "header" in spec:
        h = spec["header"]
        if isinstance(h, str):
            card["header"] = {"title": h}
        else:
            card["header"] = h
    if "sections" in spec:
        card["sections"] = [expand_section(s) for s in spec["sections"]]
    elif "widgets" in spec:  # convenience: single-section card
        card["sections"] = [expand_section({"widgets": spec["widgets"]})]
    for k in ("name", "fixedFooter", "displayStyle", "peekCardHeader",
              "cardActions", "sectionDividerStyle"):
        if k in spec:
            card[k] = spec[k]
    return card


def wrap(card: dict, fmt: str, card_id: str | None) -> dict:
    if fmt == "card":
        return card
    if fmt == "message":
        cid = card_id or f"card-{uuid.uuid4().hex[:8]}"
        return {"cardsV2": [{"cardId": cid, "card": card}]}
    if fmt == "addon":
        return {"action": {"navigations": [{"pushCard": card}]}}
    raise ValueError(f"unknown format: {fmt}")


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description="Expand shorthand to CardsV2 JSON")
    p.add_argument("--input", "-i", help="Input file (default stdin)")
    p.add_argument("--output", "-o", help="Output file (default stdout)")
    p.add_argument("--format", "-f", choices=("card", "message", "addon"),
                   default="card", help="Envelope (default: card)")
    p.add_argument("--card-id", help="cardId for message format (auto if omitted)")
    p.add_argument("--pretty", "-p", action="store_true", help="Indent output JSON")
    p.add_argument("--no-validate", action="store_true", help="Skip validation pass")
    p.add_argument("path", nargs="?", help="Input file (positional alias for --input)")
    args = p.parse_args(argv)

    src = args.input or args.path
    raw = sys.stdin.read() if not src else open(src, encoding="utf-8").read()
    try:
        spec = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"ERROR: invalid JSON: {e}", file=sys.stderr)
        return 1

    try:
        card = expand_card(spec)
    except (KeyError, ValueError) as e:
        print(f"ERROR: shorthand expansion failed: {e}", file=sys.stderr)
        return 1

    out = wrap(card, args.format, args.card_id)

    if not args.no_validate:
        errs = validate.Errors()
        if args.format == "message":
            validate.validate_message_envelope(out, errs)
            c, base = validate.get_card(out, "message")
            if c is not None:
                validate.validate_card(c, base, errs)
        elif args.format == "addon":
            try:
                inner = out["action"]["navigations"][0]["pushCard"]
                validate.validate_card(inner, "/action/navigations/0/pushCard", errs)
            except (KeyError, IndexError, TypeError):
                errs.add("/action", "malformed addon envelope")
        else:
            validate.validate_card(out, "", errs)
        if errs:
            print(f"BUILD INVALID: {len(errs.items)} error(s)", file=sys.stderr)
            for path, msg in errs.items:
                print(f"  {path or '/'}: {msg}", file=sys.stderr)
            return 1

    text = json.dumps(out, indent=2 if args.pretty else None,
                      ensure_ascii=False) + "\n"
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
