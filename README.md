# Skills

Personal marketplace of [Agent Skills](https://agentskills.io) — portable, vendor-neutral capabilities for AI coding agents.

Each top-level dir = one skill, per [agentskills.io spec](https://agentskills.io/specification): `SKILL.md` + optional `scripts/`, `references/`, `assets/`, `evals/`.

## Index

| Skill | Purpose | Runtime |
| --- | --- | --- |
| [google-ws-cards](google-ws-cards/) | Generate + validate Google Chat / Workspace add-on CardsV2 JSON. Drops into Google UIkit Card Builder. | Python 3.9+ stdlib |
| [dossier](dossier/) | Standalone phase workflow: compact spec state, audit ledger, backprop, drift checks, runtime adapters, closeout, flavors, opt-in stack lenses. | Bash 4+ (init script) |

## Install

Default path: [`skills`](https://www.npmjs.com/package/skills) CLI.

**Install all skills:**

```bash
npx skills add raisedadead/skills
```

**Install single skill:**

```bash
npx skills add raisedadead/skills -s google-ws-cards
```

```bash
npx skills add raisedadead/skills -s dossier
```

**Target specific agent** (Claude Code, Cursor, Gemini CLI, OpenCode):

```bash
npx skills add raisedadead/skills -a claude-code
```

**Install globally** (user dir, not project):

```bash
npx skills add raisedadead/skills -g
```

### Alternative: manual install

Clone or symlink into agent's skill discovery path:

```bash
git clone https://github.com/raisedadead/skills.git
ln -s "$(pwd)/skills/google-ws-cards" ~/.claude/skills/google-ws-cards
```

```bash
ln -s "$(pwd)/skills/dossier" ~/.claude/skills/dossier
```

Each `SKILL.md` self-contained — copy dir into any agent's skills folder.

## Compatibility

Skills run on any runtime supporting [Agent Skills standard](https://agentskills.io/#adoption): Claude Code, Claude.ai, Cursor, Gemini CLI, OpenCode, GitHub Copilot, VS Code, Goose, [many others](https://agentskills.io/#adoption).

## Validate

Every skill checked via official [skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref) validator:

```bash
skills-ref validate ./google-ws-cards
```

```bash
skills-ref validate ./dossier
```

## License

[MIT](LICENSE) — see individual `SKILL.md` for per-skill notes.
