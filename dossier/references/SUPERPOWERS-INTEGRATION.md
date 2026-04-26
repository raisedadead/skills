# Composition with obra/superpowers

The `obra/superpowers` plugin and `dossier` are designed to
layer cleanly. Each owns a distinct concern; running both
gives you superpowers' pipeline plus dossier's durable state
machinery.

If you don't use superpowers, skip this file — dossier stands
alone.

## Ownership map

| Concern                         | Owner       | Artefact / mechanism                                                      |
| ------------------------------- | ----------- | ------------------------------------------------------------------------- |
| Brainstorm phase                | superpowers | `brainstorming` skill → `docs/superpowers/specs/<date>-<topic>-design.md` |
| Plan authoring                  | superpowers | `writing-plans` skill → `docs/superpowers/plans/<date>-<feature>.md`      |
| Subagent dispatch               | superpowers | `subagent-driven-development` + `implementer-prompt.md` etc.              |
| Code review pass                | superpowers | `requesting-code-review` / `receiving-code-review`                        |
| Worktree management             | superpowers | `using-git-worktrees`                                                     |
| Branch finishing                | superpowers | `finishing-a-development-branch`                                          |
| TDD doctrine (Iron Law)         | superpowers | prompt-level enforcement                                                  |
| Phase plan structure            | **dossier** | `.scratchpad/dossier/PLAN.md` phase table + locked decisions              |
| Bug / finding ledger            | **dossier** | `.scratchpad/dossier/AUDIT.md`                                            |
| Per-task covenant               | **dossier** | `.scratchpad/dossier/SPEC.md`                                             |
| Sibling-test gate (file system) | **dossier** | PreToolUse TDD-gate hook + `references/COVENANT.md`                       |
| Commit cadence + format         | **dossier** | one commit per task, `type(scope): subject (PH<N>-Bxx)`                   |
| Output rebaseline 5-step        | **dossier** | `references/OUTPUT-REBASELINE.md`                                         |
| Meta-gate ratchet               | **dossier** | `references/META-GATE.md`                                                 |
| Runtime wait/resume pacing      | **dossier** | `references/BG-LOOP.md` + `references/RUNTIME-ADAPTERS.md`                |
| `/compact` recovery             | **dossier** | `references/HANDOFF.md` (recovers work state from disk)                   |
| Internal closeout               | **dossier** | `.scratchpad/dossier/closeout/<slug>.md`                                  |
| Stack lens                      | **dossier** | `lenses/<stack>.md`                                                       |

The split is clean because superpowers' artefacts are
**process-shaped** (specs, plans, agent prompts) and dossier's
artefacts are **state-shaped** (ledger, covenant, frozen
artefacts, internal phase record).

## How they compose at runtime

1. **Brainstorm** — superpowers `brainstorming` skill writes `docs/superpowers/specs/<date>-<topic>-design.md`.
2. **Plan author** — superpowers `writing-plans` skill writes `docs/superpowers/plans/<date>-<feature>.md` with checkbox tasks.
3. **Open dossier** — run `init-dossier.sh --with-superpowers --lens <stack>`. The script:
   - creates `.scratchpad/dossier/AUDIT.md` and `.scratchpad/dossier/SPEC.md` from templates,
   - symlinks `.scratchpad/dossier/PLAN.md` → `docs/superpowers/plans/<latest>.md`,
   - symlinks `.scratchpad/dossier/LENS.md` → `lenses/<stack>.md`.
4. **Pre-seed ledger** — copy any "open questions" from the brainstorm spec into `.scratchpad/dossier/AUDIT.md` as `B1, B2, …`.
5. **Per-task loop** — for each plan checkbox:
   - dossier per-task covenant: TDD round, sibling test, single commit, format `type(scope): subject (PH<N>-Bxx)`.
   - superpowers: when superpowers' subagent prompts say "complete this step", they comply with dossier's covenant naturally — RED-GREEN-COMMIT is a refinement of superpowers' Iron Law.
6. **Code review** — superpowers `requesting-code-review` runs against the commits dossier produced. Findings flow back into `.scratchpad/dossier/AUDIT.md` as new B-ids if not addressable in-flight.
7. **Branch finish** — superpowers `finishing-a-development-branch` handles the branch close. Dossier writes `.scratchpad/dossier/closeout/<slug>.md` as the internal phase record.
8. **`/compact`** — superpowers re-injects `using-superpowers` (process). Dossier recovers from disk (`.scratchpad/dossier/PLAN.md`, `AUDIT.md`, `git log`, runtime task state). They don't fight.

## Resolving the plan-doc location

Two options:

- **Symlink (recommended).** `.scratchpad/dossier/PLAN.md` → `docs/superpowers/plans/<file>.md`. One file, two readers. Init script does this with `--with-superpowers`.
- **Side-by-side.** Keep both. Superpowers reads its own; dossier reads its own; you keep them in sync manually. Diverges fast — only do this if you need different sub-phase shapes than superpowers' checkbox-list expects.

The symlink works because dossier's `PLAN.md` reader doesn't
require any specific structure beyond "phases at the top, tasks
below". Superpowers' `writing-plans` produces compatible
markdown out of the box.

## Where the doctrines differ

Superpowers' **Iron Law** says: "NO PRODUCTION CODE WITHOUT A
FAILING TEST FIRST." This is a prompt-level rule.

Dossier's **TDD gate** says: "PreToolUse hook blocks Edit on
impl files when no sibling test in `git diff`." This is a
file-system rule, enforced by the harness.

Layered: Iron Law catches "I forgot to write a test"; TDD gate
catches "I wrote a test but didn't save it / it's in a different
commit". Both apply.

The same pattern repeats for commit hygiene: superpowers leaves
commit hygiene to convention; dossier's covenant + cmd-git-rules
hook enforces it.

## Where the doctrines clash (and resolution)

- **Squash vs one-commit-per-task.** Superpowers' `finishing-a-development-branch` sometimes squashes. Dossier wants one commit per task preserved for traceability.
  - **Resolution.** Squash _across_ tasks within a phase is fine for the merge commit, _but the local branch keeps one commit per task_ until merged. The merge commit message can reference the internal closeout if the user wants.
- **Plan-doc placeholders.** Superpowers' `writing-plans` may include checkboxes like "[ ] Add X". Dossier's covenant expects a B-id per task.
  - **Resolution.** When converting checkboxes to dossier tasks, assign B-ids on the fly: `[ ] B7: Add X`. Cross-reference in `AUDIT.md`.

## Minimum viable composition

If you want to try them together with minimum friction:

1. Install superpowers as a plugin.
2. Install dossier (symlink into `.claude/skills/`).
3. Run superpowers' `brainstorming` and `writing-plans` for the next initiative.
4. Run `dossier`'s init script with `--with-superpowers`.
5. Drop into superpowers' execution flow with dossier's covenant active.

You'll notice: superpowers handles the "what" and the "who"
(plan + dispatch); dossier handles the "how" and the internal trail
(covenant + ledger + closeout).
