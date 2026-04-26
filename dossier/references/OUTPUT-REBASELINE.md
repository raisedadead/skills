# Output rebaseline — strict 5-step order

When a fix changes a recorded output, follow this order exactly.
No exceptions. The pattern is identical across stacks — only
the runner / artefact name varies.

## What counts as a "recorded output"

| Stack         | Output type                | Example artefact                       |
| ------------- | -------------------------- | -------------------------------------- |
| Web frontend  | PNG snapshot               | `tests/visual/__snapshots__/*.png`     |
| Backend API   | OpenAPI / contract dump    | `openapi.v2.yaml` / `contracts/*.json` |
| CLI tool      | Golden stdout / stderr     | `tests/golden/*.txt`                   |
| Library       | Public API surface         | `api-surface.json` / `*.api.md`        |
| Data pipeline | Schema / fixture roundtrip | `schema.json` / `fixtures/*.parquet`   |
| Infra / IaC   | Plan diff / state export   | `tf-plan.txt` / `pulumi-preview.json`  |
| Mobile        | Snapshot images            | `__Snapshots__/*.png` (iOS/Android)    |
| ML pipeline   | Eval-set scores / outputs  | `evals/<name>/results.json`            |
| Docs          | Rendered HTML / PDF        | `dist/api-docs/*.html`                 |

The rule: **structural change → recorded output changes →
rebaseline + commit together**.

## Order

1. **Make the fix** — code, schema, config, CSS, IaC.

2. **Build / regenerate** so downstream readers see new output.

   ```bash
   # web                 → pnpm build / next build
   # backend (openapi)   → make openapi    (re-emits from handlers)
   # cli (goldens)       → no build; tests run against bin
   # library (surface)   → api-extractor run / cargo public-api
   # iac (plan)          → terraform plan -out=tfplan
   # data (schema)       → dbt compile / sqlfluff render
   # ml (evals)          → poetry run python -m evals.run
   ```

3. **Run unbaselined**. Read the failure list. Confirm it
   matches the intent of the fix. **NO `--update-snapshots`,
   no `--write`, no `apply`** at this step.

   ```bash
   # web        → pnpm exec playwright test
   # backend    → pnpm test:contract              (asserts current vs frozen)
   # cli        → bats tests/golden               (asserts stdout vs frozen)
   # library    → api-extractor run --no-write
   # iac        → terraform show tfplan | diff baseline.txt -
   # data       → dbt test --select <model>+
   # ml         → python -m evals.compare         (asserts deltas inside band)
   ```

4. **Run baselined / accept**. Files change.

   ```bash
   # web        → pnpm exec playwright test --update-snapshots
   # backend    → make openapi && git add openapi.v2.yaml
   # cli        → BATS_UPDATE_GOLDEN=1 bats tests/golden
   # library    → api-extractor run --local
   # iac        → cp tfplan.new baseline.txt
   # data       → re-emit schema dump
   # ml         → python -m evals.update-baseline
   ```

5. **Commit fix + rebaselined goldens together.**

   ```bash
   git add <source files> <golden files>
   git commit -m "fix(<scope>): <subject> (PH<N>-Bxx)"
   ```

## What never happens

- ❌ Accept goldens before reading the unbaselined diff.
  → You'd commit goldens that match a bug, not the intent.
- ❌ Commit a fix without its rebaselined goldens.
  → CI red on the next PR.
- ❌ Skip step 2 (build / regenerate).
  → Tests compare against stale output.
- ❌ Two parallel rebaselines on overlapping artefacts.
  → Lost-update merge mess.

## Scoped vs full rebaseline

**Scoped** (preferred when one unit changed):

```bash
# web
pnpm exec playwright test playground-card -g 'button' --update-snapshots
# backend
make openapi-route ROUTE=/v2/orders
# cli
BATS_UPDATE_GOLDEN=1 bats tests/golden/auth.bats
```

Smaller diff, cleaner commit.

**Full** (necessary when shared / global changed):

```bash
pnpm exec playwright test --update-snapshots         # full visual
make openapi                                          # full OpenAPI re-emit
BATS_UPDATE_GOLDEN=1 bats tests/golden                # full CLI golden
```

Use `git status` to check the blast radius before committing.

## Long-running rebaselines go background

Any rebaseline > 30s wall clock uses the selected runtime adapter,
never shell `sleep`. See `BG-LOOP.md`.

```
long_command({
  command: "<rebaseline cmd> 2>&1 | tail -3",
  description: "Full rebaseline after <fix>"
})

resume_after_wait({
  delaySeconds: <120-300>,
  reason: "Rebaseline pacing"
})
```

## When the diff looks "wrong"

E.g. you changed 10 source files but only 3 goldens updated.
Initial reaction: "did the rebaseline miss?"

Common explanations:

- The recorded output covers a strict subset (only some routes /
  components / commands are screenshotted / captured). The
  unrecorded ones changed structurally but no golden existed to
  update — behaviour is correct, no bug.
- The change was internal (helper refactor) and produced no
  observable surface delta. No goldens should change.
- The build cache served stale output. Re-run step 2.

Action: confirm the recorded set in the spec / config file
(e.g. `playground-card.spec.ts`, `openapi.config.ts`,
`tests/golden/manifest.txt`). If a unit _should_ be recorded
but isn't, file a separate ledger entry — it's a coverage gap,
not a rebaseline failure.
