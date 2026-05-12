# Marker guard hook

Optional Claude Code `PreToolUse` hook. Fires on `Edit|Write|MultiEdit` and blocks edits whose new content carries phase, stage, or audit-id markers in comments — `// Phase 1:`, `// Step N:`, `// Stage 3`, `// V11 (Phase 3 / A7):`, `// PH3-B7`.

Phase tracking belongs in `.scratchpad/dossier/PLAN.md` and `SPEC.md §B`. Source must stay phase-agnostic.

Script: `scripts/marker-guard.py`. Python 3 stdlib only.

## Claude Code settings

Project-local `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 <skill-dir>/scripts/marker-guard.py"
          }
        ]
      }
    ]
  }
}
```

Replace `<skill-dir>` with the installed dossier skill path. If dossier is vendored into the repo, use a project-relative path. Co-installs cleanly alongside `tdd-gate.py` — both can register on the same `Edit|Write|MultiEdit` matcher.

## Behavior

Exit `0`: allow edit. Exit `2`: block edit and feed stderr to Claude.

Pass-through cases:

- File path under `.scratchpad/dossier/` or named `PLAN.md`, `SPEC.md`, `AUDIT.md`, `LENS.md`.
- Phase token inside a string literal (regex anchors on comment prefixes only — `//`, `#`, `--`, `/*`, `*`, `<!--`, `;`).
- Tool other than `Edit | Write | MultiEdit`.

Block message tells the agent to:

1. Drop the phase / audit-id prefix; keep any why-tail (workaround reference, non-obvious invariant, upstream-bug link).
1. Move the phase or audit reference into `SPEC.md §B` as a finding row.

Emergency bypass: `DOSSIER_MARKER_GUARD=off`. Use only with written rationale in `AUDIT.md`.

## Verify the guard

Self-contained smoke test in `scripts/test-marker-guard.sh`. Exercises the leak pattern (`V11 (Phase 3 / A7)`), bare phase / step / stage forms, audit-id form (`PH3-B7`), block comments, string-literal allowance, dossier-path allowance, `MultiEdit` chunks, bypass env, and non-Edit tool ignore:

```bash
bash <skill-dir>/scripts/test-marker-guard.sh
```

Exits `0` on `ok`. Run after editing `marker-guard.py` or its regex set.
