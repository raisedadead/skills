# Per-task covenant

Rules every commit in phase obeys. Project-tunable in
`.scratchpad/dossier/SPEC.md`.

## Positive — every task does this

- **Exactly one commit per task.** No squash-later. No partial commits.
- **Vertical slice.** Each task proves one behavior/outcome through
  public interface; no layer-only tasks unless layer itself is
  public surface.
- **Title only.** No commit body unless "why" non-obvious. Diff + linked B-id explain "what".
- **Format:** `type(scope): subject (PH<N>-Bxx)`
  - `type` ∈ `feat` / `fix` / `test` / `chore` / `docs` / `refactor` / `perf` / `build` / `ci`
  - `scope` = project unit — package / service / module / surface (`api`, `worker`, `cli`, `migration`, `infra`, `evals`, etc.)
  - `subject` imperative mood, ≤ 50 chars
  - `(PH<N>-Bxx)` ties commit to row in `AUDIT.md §B`
- **Sibling test in `git diff`.** PreToolUse TDD gate blocks Edit on impl files when no sibling test uncommitted in `git diff HEAD`. Write failing test first.
- **Rebaselined output included.** When fix changes recorded output (snapshots, OpenAPI, goldens, schema dumps, terraform plan baseline), updated artefact lands in same commit (see `OUTPUT-REBASELINE.md`).
- **Meta-gate updates in same commit.** When structural rule strengthens (coverage threshold, public-API allowlist add, env-var allowlist, terraform deny-list), meta-test change lands with impl change.
- **Update runtime task state.** Use selected adapter: `task_start` on start, `task_done` on finish. State must survive or be reconstructable after compact / session loss.
- **Update `AUDIT.md §B` at phase boundary.** Finding table canonical.

## Negative — no task ever does this

| Rule | Why |
| ---- | --- |
| Never `git add -A` / `git add .` | Catches unrelated drift, parallel-session work, build artefacts. |
| Never `--no-verify` / `--no-gpg-sign` | Hooks exist for reason. If broken, fix them, don't skip. |
| Never `git commit --amend` after publish | Rewrites public history. |
| Never HEREDOC in `git commit -m "..."` | cmd-git-rules hook treats heredoc as suspicious. |
| Never backticks in commit messages | PreToolUse pattern sees command substitution. |
| Never `git reset --hard` on tracked changes | May be parallel session's WIP. |
| Never `git push` | User owns push. |
| Never `gh pr create` | User owns PR. |
| Never `npm publish` / `cargo publish` / `pip publish` | User owns release. |
| Never `terraform apply` / `kubectl apply -f` / `dbt run` against prod | User owns deploy / apply. |
| Never edit `.env` files | Read-blocked + write-blocked. |
| Never co-author lines | Disabled in user settings; redundant noise. |
| Never touch parallel-session work without confirmation | Multiple sessions may run concurrently. |

## Worked examples

### Web frontend phase tail (PNG rebaseline + tokens)

```
b15e4a6 test(docs): lock preview spans full card chrome (PH9-B2 not-repro)
09c1657 fix(docs): explicit type=button on .showcase__tab (PH9-B14)
b4e718f fix(docs): swap hex literals in showcase.css for tokens (PH9-B13)
c90490f test(docs): lock tooltip + data-table behavioural contracts (PH9-B6)
```

### Backend service phase tail (OpenAPI freeze + migration)

```
9a1c33d feat(api): add idempotency_key to POST /v2/orders (PH3-B7)
6d8e2b1 test(api): contract test idempotent retry returns 200 not 409 (PH3-B7)
3b71a04 fix(db): linear migration 0042 — add tier column, default free (PH3-B5)
e217c50 test(db): migration 0042 idempotent on rerun (PH3-B5)
```

### CLI tool phase tail (golden stdout + exit codes)

```
2c4d1f6 fix(cli): exit 64 on usage error not 1 (PH2-B3)
8e91207 test(cli): golden stdout for `tool init --dry-run` (PH2-B2)
4f01a8a refactor(cli): split flag parser, add no-color sentinel (PH2-B1)
```

### Library phase tail (public API surface + semver)

```
9f1e2c8 feat(core): rename `compute()` → `evaluate()` — breaking (PH4-B9)
1c4e007 test(core): public API surface frozen at v2.0 (PH4-B9)
3a72f1d fix(auth): null-safe token refresh (PH4-B6)
```

Pattern across all four: each subject ≤ 50 chars, names
surface (`scope`), states outcome, ends with P-Bxx tag.
No bodies. No emoji. Sibling test always in diff. Phase closeout
written under `.scratchpad/dossier/closeout/`, not committed as
package-manager changeset.
