# Per-task covenant

Rules every commit in phase obeys. Project-tunable in
`.scratchpad/dossier/SPEC.md`.

## Positive — every task does this

- **Exactly one commit per task.** No squash-later. No partial commits.
- **Test + impl bundled.** Single commit contains the failing test AND the implementation that makes it green. No separate `test:` commit ahead of `feat:`/`fix:`. RED-GREEN happens in worktree, not git log.
- **Vertical slice.** Each task proves one behavior/outcome through
  public interface; no layer-only tasks unless layer itself is
  public surface.
- **Title only.** No commit body unless "why" non-obvious. Diff explains "what".
- **Format:** `type(scope): subject`
  - `type` ∈ `feat` / `fix` / `test` / `chore` / `docs` / `refactor` / `perf` / `build` / `ci`
  - `scope` = project unit — package / service / module / surface (`api`, `worker`, `cli`, `migration`, `infra`, `evals`, etc.)
  - `subject` imperative mood, ≤ 50 chars
  - No phase/bug suffix in commit message. Phase tracking lives in `AUDIT.md §B` only.
- **Sibling test in `git diff`.** PreToolUse TDD gate (`scripts/tdd-gate.py`) blocks Edit on impl files when no sibling test/evidence exists in current worktree. Write failing test first; commit together with impl.
- **Rebaselined output included.** When fix changes recorded output (snapshots, OpenAPI, goldens, schema dumps, terraform plan baseline), updated artefact lands in same commit (see `OUTPUT-REBASELINE.md`).
- **Meta-gate updates in same commit.** When structural rule strengthens (coverage threshold, public-API allowlist add, env-var allowlist, terraform deny-list), meta-test change lands with impl change.
- **Update runtime task state.** Use selected adapter: `task_start` on start, `task_done` on finish. State must survive or be reconstructable after compact / session loss.
- **Update `AUDIT.md §B` at phase boundary.** Finding table canonical.
- **Cause stated, not symptom.** When the task fixes a bug, the `AUDIT.md §B` `fix` column (or commit body when present) names the root cause in one phrase, not the surface patch. _Symptom:_ "null check on `user.email`". _Cause:_ "OAuth refresh path drops email claim — refresh response unmarshalled from wrong field." Surface patches that don't trace to a cause require an explicit `C<n>` deferred-cause row.
- **Surgical scope.** Touch the smallest set of files that proves the behavior. Fan-out edits (>5 files for one task, or any file outside the named `§I` interfaces) require a one-line `PLAN.md` exception recorded before the edit.

## Negative — no task ever does this

| Rule                                                                  | Why                                                                                                                                                     |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Never `git add -A` / `git add .`                                      | Catches unrelated drift, parallel-session work, build artefacts.                                                                                        |
| Never `--no-verify` / `--no-gpg-sign`                                 | Hooks exist for reason. If broken, fix them, don't skip.                                                                                                |
| Never `git commit --amend` after publish                              | Rewrites public history.                                                                                                                                |
| Never HEREDOC in `git commit -m "..."`                                | cmd-git-rules hook treats heredoc as suspicious.                                                                                                        |
| Never backticks in commit messages                                    | PreToolUse pattern sees command substitution.                                                                                                           |
| Never `git reset --hard` on tracked changes                           | May be parallel session's WIP.                                                                                                                          |
| Never `git push`                                                      | User owns push.                                                                                                                                         |
| Never `gh pr create`                                                  | User owns PR.                                                                                                                                           |
| Never `npm publish` / `cargo publish` / `pip publish`                 | User owns release.                                                                                                                                      |
| Never `terraform apply` / `kubectl apply -f` / `dbt run` against prod | User owns deploy / apply.                                                                                                                               |
| Never edit `.env` files                                               | Read-blocked + write-blocked.                                                                                                                           |
| Never co-author lines                                                 | Disabled in user settings; redundant noise.                                                                                                             |
| Never touch parallel-session work without confirmation                | Multiple sessions may run concurrently.                                                                                                                 |
| Never write phase/stage markers in source code                        | `// Phase 1:`, `// Step N:`, `// PH3-B7` belong in `PLAN.md` / `AUDIT.md`, not source files. Source must be phase-agnostic.                             |
| Never narrate work in code comments                                   | `// Now we validate input`, `// First, fetch user` = noise. Code shows _what_; comments show _why_ only (e.g. workaround refs, non-obvious invariants). |

## Worked examples

Each example below = one phase tail. Every commit bundles its sibling test + impl. No phase/bug tag in subject — `AUDIT.md §B` is the canonical ledger.

### Web frontend phase tail (PNG rebaseline + tokens)

```
b15e4a6 fix(docs): lock preview spans full card chrome
09c1657 fix(docs): explicit type=button on .showcase__tab
b4e718f fix(docs): swap hex literals in showcase.css for tokens
c90490f test(docs): lock tooltip + data-table behavioural contracts
```

### Backend service phase tail (OpenAPI freeze + migration)

```
9a1c33d feat(api): add idempotency_key to POST /v2/orders
3b71a04 fix(db): linear migration 0042 — add tier column, default free
e217c50 fix(db): migration 0042 idempotent on rerun
```

### CLI tool phase tail (golden stdout + exit codes)

```
2c4d1f6 fix(cli): exit 64 on usage error not 1
8e91207 feat(cli): golden stdout for `tool init --dry-run`
4f01a8a refactor(cli): split flag parser, add no-color sentinel
```

### Library phase tail (public API surface + semver)

```
9f1e2c8 feat(core): rename `compute()` → `evaluate()` — breaking
3a72f1d fix(auth): null-safe token refresh
```

Pattern across all four: each subject ≤ 50 chars, names
surface (`scope`), states outcome. No bodies. No emoji. No phase tag.
Sibling test always in same commit's diff. Phase closeout written
under `.scratchpad/dossier/closeout/`, not committed as
package-manager changeset.
