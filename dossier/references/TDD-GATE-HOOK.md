# TDD gate hook

Optional Claude Code `PreToolUse` hook. Fires on `Edit|Write|MultiEdit`,
not every turn. It blocks impl/config edits only when:

- `.scratchpad/dossier/SPEC.md` exists.
- Target path looks like source/config/contract.
- Current worktree has no test, meta-gate, golden, contract, schema, or
  recorded-output evidence.

Script: `scripts/tdd-gate.py`. It uses Python 3 stdlib only.

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
            "command": "python3 <skill-dir>/scripts/tdd-gate.py"
          }
        ]
      }
    ]
  }
}
```

Replace `<skill-dir>` with installed dossier skill path. If dossier is
vendored into the repo, use project-relative path.

## Behavior

Exit `0`: allow edit. Exit `2`: block edit and feed stderr to Claude.

Block message tells agent to:

1. Write/update failing behavior test first.
2. Run narrow test, confirm RED.
3. Re-attempt impl edit.
4. For config/contract/output changes, add meta-gate or recorded output.

Emergency bypass: `DOSSIER_TDD_GATE=off`. Use only with written rationale
in `AUDIT.md`.

## Verify the gate

Self-contained smoke test in `scripts/test-tdd-gate.sh`. Exercises the
five branches (unevidenced impl edit blocks, untracked test allows,
meta-gate allows, test-file write allows, inactive dossier allows) in a
throwaway git repo:

```bash
bash <skill-dir>/scripts/test-tdd-gate.sh
```

Exits `0` on `ok`. Run after editing `tdd-gate.py` or its evidence
heuristics.
