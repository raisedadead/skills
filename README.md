# Skills

Personal collection of [Agent Skills](https://agentskills.io) — portable, vendor-neutral capabilities for AI agents.

Each top-level directory is one skill, structured per the [agentskills.io specification](https://agentskills.io/specification): a `SKILL.md` plus optional `scripts/`, `references/`, and `assets/`.

## Skills

| Skill                               | Purpose                                                                                                                                                    |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [google-ws-cards](google-ws-cards/) | Generate and validate Google Chat / Workspace add-on CardsV2 JSON. Drops cleanly into the [UIkit Builder](https://addons.gsuite.google.com/uikit/builder). |

## Using these skills

Compatible with any agent runtime that supports the agentskills.io standard, including Claude Code, Claude.ai, Gemini CLI, Cursor, OpenCode, and others — see the [full client list](https://agentskills.io/#adoption).

### Claude Code

Symlink or clone into the discovery path:

```bash
ln -s "$(pwd)/google-ws-cards" ~/.claude/skills/google-ws-cards
```

### Manual invocation

Each skill's `SKILL.md` is self-contained — copy the directory into your agent's skills folder.

## Validation

Every skill in this repo is checked with the official [skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref) validator:

```bash
skills-ref validate ./google-ws-cards
```

## License

MIT — see individual `SKILL.md` for per-skill licensing.
