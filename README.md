# Skills

A personal marketplace of [Agent Skills](https://agentskills.io) — portable, vendor-neutral capabilities for AI coding agents.

Each top-level directory is one skill, structured per the [agentskills.io specification](https://agentskills.io/specification): a `SKILL.md` plus optional `scripts/`, `references/`, `assets/`, and `evals/`.

## Index

| Skill | Purpose | Runtime |
| --- | --- | --- |
| [google-ws-cards](google-ws-cards/) | Generate and validate Google Chat / Workspace add-on CardsV2 JSON. Drops into the Google UIkit Card Builder. | Python 3.9+ stdlib |
| [dossier](dossier/) | Stack-neutral phase workflow with scratchpad plan/audit/spec, closeout, flavors, runtime adapters, and opt-in stack lenses. | Bash 4+ (init script) |

## Install

The default install path is the [`skills`](https://www.npmjs.com/package/skills) CLI.

**Install every skill in this repo:**

```bash
npx skills add raisedadead/skills
```

**Install a single skill:**

```bash
npx skills add raisedadead/skills -s google-ws-cards
```

**Target a specific agent** (e.g. Claude Code, Cursor, Gemini CLI, OpenCode):

```bash
npx skills add raisedadead/skills -a claude-code
```

**Install globally** (user directory, not project):

```bash
npx skills add raisedadead/skills -g
```

### Alternative: manual install

Clone or symlink directly into your agent's skill discovery path:

```bash
git clone https://github.com/raisedadead/skills.git
ln -s "$(pwd)/skills/google-ws-cards" ~/.claude/skills/google-ws-cards
```

Each `SKILL.md` is self-contained — copy the directory into any agent's skills folder.

## Compatibility

These skills run on any agent runtime that supports the [Agent Skills standard](https://agentskills.io/#adoption), including Claude Code, Claude.ai, Cursor, Gemini CLI, OpenCode, GitHub Copilot, VS Code, Goose, and [many others](https://agentskills.io/#adoption).

## Validate

Every skill is checked with the official [skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref) validator:

```bash
skills-ref validate ./google-ws-cards
```

## License

[MIT](LICENSE) — see individual `SKILL.md` files for per-skill notes.
