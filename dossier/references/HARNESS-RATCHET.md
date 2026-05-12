# Harness ratchet — earn every rule, retire what stops earning

Dossier is a harness in the sense [Vtrivedy10 / dexhorthy / HumanLayer / Anthropic / Birgitta Böckeler use the term](https://www.parallel.ai/blog/agent-harnesses): the prompts, tools, hooks, sandboxes, subagents, feedback loops, and recovery paths wrapped around a model. The "ratchet" is the discipline that keeps the harness small and honest:

> Every rule traces to a past failure. Every rule that no longer earns its keep gets proposed for retirement.

Without that ratchet, the skill grows by accretion — every clever idea sticks; nothing leaves. With it, the skill stays roughly the size of its real failure history.

## Adding a rule

A rule lands only when a concrete failure is on file. The failure can live in any of:

- A `B<n>` row in `SPEC.md §B` (the canonical ledger).
- A Detail section in `AUDIT.md`.
- A row in a project's `.scratchpad/dossier/.lessons.md` (or the kernel-wide store pointed to by `--lessons-home`).
- A line in `CHANGELOG.md` citing an external incident.

The rule itself can take any of these shapes:

- A hook (`commit-guard.py`, `marker-guard.py`, `tdd-gate.py`, `post-commit-test.py`).
- A script primitive (`drift-check.sh`, `dossier-status.sh`, etc.).
- A doc clause that the operator is expected to read.

Whatever the shape, the new rule earns a line in `CHANGELOG.md` of the form:

```
<version> <date> — <one-line rule summary> [earned-by: <failure ref>]
```

If the `earned-by` reference is empty or "general best practice", the rule should not land. "We might need this someday" is the opposite of the ratchet.

## Retiring a rule

When the underlying failure mode stops recurring — usually because a better model, a tighter platform primitive, or a stricter upstream hook now catches it — propose retirement. The retirement entry in `CHANGELOG.md` cites the rule's original `earned-by` and the reason it's no longer needed:

```
<version> <date> — retire <rule> [was earned-by: <ref>; now redundant: <reason>]
```

Outdated scaffolding raises the cost of every dossier without raising the floor of any phase. The skill should shrink as the model grows.

## Audit cadence

At least once per skill release, walk `CHANGELOG.md` end-to-end and ask, of each entry, "is this still earning its keep?". Anything that isn't is a retirement candidate.

## What this means in practice

- New script ↔ new hook ↔ new doc clause ↔ new `CHANGELOG.md` entry with `earned-by:`.
- No `earned-by:` ↔ no land.
- A `.lessons.md` row is the most lightweight `earned-by:` — write lessons first, see if they repeat, then propose a rule if they do.
- The skill version stays in `SKILL.md` frontmatter. Bump on every user-visible behavior change (default footprint, new flag, new hook, new script primitive, new ledger schema).

## See also

- `CHANGELOG.md` — the ledger this discipline maintains.
- `EXAMPLES.md` — earned-by-failure commit-tail patterns per stack.
- `FAILURE-MODES.md` — stack-neutral footgun catalogue.
- The harness-engineering article that names the pattern: *Harness Engineering: The Model + Everything Built Around It.*
