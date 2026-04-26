# Lens — Data pipeline

For ETL / ELT / orchestrated data jobs — dbt / Airflow / Dagster /
Spark / Beam / DuckDB — where the schema, fixture roundtrip, and
lineage are the contract.

## Surface vocabulary

- **Unit:** model / table / DAG / job (`stg_orders`, `fct_revenue`).
- **Output:** schema (column names + types + constraints), row count + checksum, lineage (upstream / downstream), partition manifest.
- **Contract:** schema diff + fixture roundtrip + idempotency on rerun + freshness SLA + row-count band.

## Specific gates (meta-gate extensions)

- **Schema freeze.** `schema.json` (or `target/manifest.json` for dbt) committed; CI regenerates and `git diff --exit-code`. Column add/drop/type-change → diff → fail.
- **Fixture roundtrip.** For every model: a fixture lands a known input → run model → assert output matches frozen golden.
- **Idempotency on rerun.** Run model twice; assert second run produces identical output (no duplicates, no drift). Meta-gate via test pattern.
- **Row-count band.** Per partition, row count within `[low, high]`. Meta-gate fires if outside (often early indicator of upstream breakage).
- **No `SELECT *` in production models.** dbt: `compile_sql` regex offenders. SQL: lint with sqlfluff rule `L044`.
- **Lineage manifest.** Each model declares `ref()`s; meta-gate cross-references against `target/manifest.json`'s `parent_map`.
- **Freshness SLA.** Each source declares `freshness:` block; meta-gate rejects sources without freshness.
- **No `current_timestamp()` in models.** Use injected `{{ run_started_at }}` so reruns are deterministic.
- **NULL allow-list.** Per column: NULL allowed yes/no, declared as `not_null` test. Meta-gate diffs schema vs test set.

## Output rebaseline specifics

| Step             | Command                                          |
| ---------------- | ------------------------------------------------ |
| Build / compile  | `dbt compile` / `prefect deployment build`       |
| Regenerate       | `dbt docs generate` (manifest) / `dbt run -t ci` |
| Unbaselined diff | `git diff target/manifest.json schema.json`      |
| Read failures    | added/removed/typed columns listed               |
| Accept           | stage the regenerated artefact                   |
| Fixture run      | `dbt build --select <model>+`                    |

Goldens: `schema.json`, `target/manifest.json` (subset),
`fixtures/<model>/expected.csv` (or parquet for big sets).

## Probe specifics

- File: `_probe-<slug>.sql` (read-only) / `_probe_<slug>_test.py`
- Runner: `dbt run-operation _probe_<slug>` / `psql -f _probe-<slug>.sql` / `pytest -k _probe -s`
- Dump shape: row counts, checksums per partition, distinct-value counts, NULL counts, sample rows (LIMIT 10).
- Common dump targets: duplicate-key counts (`SELECT id, count(*) GROUP BY 1 HAVING count(*) > 1 LIMIT 10`), join cardinalities, partition pruning effectiveness.

## Stack footguns

- **Time-zone drift between source and warehouse.** Source emits in UTC, warehouse stores naive — joins on date misalign. → store with TZ; assert in fixture.
- **Idempotency broken by `current_timestamp` in models.** Run #1 and #2 differ. → use `{{ run_started_at }}` or pass timestamp as variable.
- **Race on incremental model with two schedulers.** Both write the same partition. → claim partition via lock table or per-run scratch schema.
- **Schema migration changes nullability.** Existing rows have NULL but new constraint forbids it → migration fails on apply. → backfill before constraining; meta-gate on order in migration files.
- **`MERGE` on non-unique key.** Updates wrong row. → meta-gate on MERGE statements lacking `unique_key:` config.
- **Cartesian join hidden by selectivity.** Pre-prod: small data, fast. Prod: explodes. → assert join cardinality in tests.
- **Float vs decimal in money columns.** Sum drift. → meta-gate flags `FLOAT` for currency-named columns.
- **CSV roundtrip drops type.** Date parsed as string on reload → comparison fails. → use parquet for golden fixtures.
- **`current_user` differs across CI / local / prod.** Hardcoded user in DDL → permissions drift. → use roles, not users.

## Phase shape hint

Typical sub-phases for a data-pipeline phase:

- P0 — schema baseline freeze + fixture scaffold
- P1 — meta-gates (idempotency, row-count band, lineage, freshness)
- P2 — incremental model contract (per-model TDD rounds)
- P3 — backfill scripts + downtime plan
- P4 — observability (run-time band, alert thresholds)
- P5 — release / cut + changeset (service variant — operators read this)
