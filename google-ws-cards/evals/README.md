# Evals

Cheap manual evals for the `google-ws-cards` skill.

## Files

- `prompts.jsonl` — 7 should-trigger + 5 should-not-trigger labeled prompts
- `rubric.md` — pass/weak/fail criteria
- `results/` — per-prompt transcripts (gitignored)

## Running

Skill is not symlinked into the user's Claude skills dir, so agents won't auto-discover it. Two options:

### Option 1 — manual in Claude Code

1. Symlink: `ln -s "$(pwd)/../" ~/.claude/skills/google-ws-cards` (from this dir)
2. Paste each prompt into a fresh session
3. Save transcript to `results/<id>.md`
4. Grade against `rubric.md`

### Option 2 — subagent dispatch (what this session did)

Dispatch a fresh agent with prompt:

> Read `/Users/mrugesh/DEV/skills/google-ws-cards/SKILL.md` and treat it as an installed skill. Then answer this user request using ONLY the skill's workflow: `<prompt>`

Collect agent response, grade against rubric. No persistent state; re-run any time.

## Grading

For each result:

- Did the skill fire at all? (Check: agent read SKILL.md, cited workflow)
- Template pick — matches `expected_template`?
- Validator run — evidence of `OK` from `validate.py`?
- Output contract — JSON block + format + UIkit URL + validation confirmation?

Every **Fail** becomes either a gotcha line in `SKILL.md` or a new template. Re-run after patching.
