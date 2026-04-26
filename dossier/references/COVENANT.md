# Per-task covenant

The rules every commit in a phase obeys. Project-tunable in
`.scratchpad/dossier/SPEC.md`.

## Positive — every task does this

- **Exactly one commit per task.** No squash-later. No partial commits.
- **Title only.** No commit body unless the "why" is non-obvious. The diff and the linked B-id explain the "what".
- **Format:** `type(scope): subject (P<N>-Bxx)`
  - `type` ∈ `feat` / `fix` / `test` / `chore` / `docs` / `refactor` / `perf` / `build` / `ci`
  - `scope` is a project unit — package / service / module / surface (`api`, `worker`, `cli`, `migration`, `infra`, `evals`, etc.)
  - `subject` in imperative mood, ≤ 50 chars
  - `(P<N>-Bxx)` ties the commit to a row in `AUDIT.md` Resolution log
- **Sibling test in `git diff`.** The PreToolUse TDD gate blocks Edit on impl files when no sibling test is uncommitted in `git diff HEAD`. Write the failing test first.
- **Rebaselined output included.** When a fix changes any recorded output (snapshots, OpenAPI, goldens, schema dumps, terraform plan baseline), the updated artefact lands in the same commit (see `OUTPUT-REBASELINE.md`).
- **Meta-gate updates in same commit.** When a structural rule strengthens (coverage threshold, public-API allowlist add, env-var allowlist, terraform deny-list), the meta-test change lands with the impl change.
- **Update runtime task state.** Use the selected adapter: `task_start` on start, `task_done` on finish. State must survive or be reconstructable after compact / session loss.
- **Append to `AUDIT.md` Resolution log at phase boundary.** Per-section `Status:` drifts; the table is canonical.

## Negative — no task ever does this

| Rule                                                                  | Why                                                                   |
| --------------------------------------------------------------------- | --------------------------------------------------------------------- |
| Never `git add -A` / `git add .`                                      | Catches unrelated drift, parallel-session work, build artefacts.      |
| Never `--no-verify` / `--no-gpg-sign`                                 | Pre-commit hooks exist for a reason. If broken, fix them, don't skip. |
| Never `git commit --amend` after publish                              | Rewrites public history.                                              |
| Never HEREDOC in `git commit -m "..."`                                | The cmd-git-rules hook treats heredoc as suspicious.                  |
| Never backticks in commit messages                                    | PreToolUse pattern matches command substitution → hook fires.         |
| Never `git reset --hard` on tracked changes                           | May be a parallel session's WIP.                                      |
| Never `git push`                                                      | User owns push.                                                       |
| Never `gh pr create`                                                  | User owns PR.                                                         |
| Never `npm publish` / `cargo publish` / `pip publish`                 | User owns release.                                                    |
| Never `terraform apply` / `kubectl apply -f` / `dbt run` against prod | User owns deploy / apply.                                             |
| Never edit `.env` files                                               | Read-blocked + write-blocked.                                         |
| Never co-author lines                                                 | Disabled in user settings; redundant noise.                           |
| Never touch parallel-session work without confirmation                | Multiple sessions may run concurrently.                               |

## Worked examples

### Web frontend phase tail (PNG rebaseline + tokens)

```
b15e4a6 test(docs): lock preview spans full card chrome (P9-B2 not-repro)
09c1657 fix(docs): explicit type=button on .showcase__tab (P9-B14)
b4e718f fix(docs): swap hex literals in showcase.css for tokens (P9-B13)
c90490f test(docs): lock tooltip + data-table behavioural contracts (P9-B6)
```

### Backend service phase tail (OpenAPI freeze + migration)

```
9a1c33d feat(api): add idempotency_key to POST /v2/orders (P3-B7)
6d8e2b1 test(api): contract test idempotent retry returns 200 not 409 (P3-B7)
3b71a04 fix(db): linear migration 0042 — add tier column, default free (P3-B5)
e217c50 test(db): migration 0042 idempotent on rerun (P3-B5)
```

### CLI tool phase tail (golden stdout + exit codes)

```
2c4d1f6 fix(cli): exit 64 on usage error not 1 (P2-B3)
8e91207 test(cli): golden stdout for `tool init --dry-run` (P2-B2)
4f01a8a refactor(cli): split flag parser, add no-color sentinel (P2-B1)
```

### Library phase tail (public API surface + semver)

```
9f1e2c8 feat(core): rename `compute()` → `evaluate()` — breaking (P4-B9)
1c4e007 test(core): public API surface frozen at v2.0 (P4-B9)
3a72f1d fix(auth): null-safe token refresh (P4-B6)
```

Pattern across all four: each subject ≤ 50 chars, names the
surface (`scope`), states an outcome, ends with the P-Bxx tag.
No bodies. No emoji. Sibling test always in the diff. Phase closeout
is written under `.scratchpad/dossier/closeout/`, not committed as a
package-manager changeset.
