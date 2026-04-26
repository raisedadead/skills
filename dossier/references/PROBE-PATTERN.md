# Probe-then-fix pattern

When an assertion fails for unclear reasons, write a throwaway
runtime probe to dump state, read the dump, then delete the
probe before commit. The pattern works for any stack — only the
runtime changes.

## Naming

`_probe-<slug>.<stack-suffix>` — leading underscore sorts at top

- signals "throwaway".

| Stack         | Suffix                                                      |
| ------------- | ----------------------------------------------------------- |
| Web frontend  | `_probe-<slug>.behaviour.spec.ts` (Playwright)              |
| Backend       | `_probe-<slug>_test.go` / `test_probe_<slug>.py`            |
| CLI           | `_probe-<slug>.bats`                                        |
| Library       | `_probe-<slug>.spec.ts`                                     |
| Data pipeline | `_probe-<slug>.sql` (SELECT-only) / `_probe-<slug>_test.py` |
| Infra / IaC   | `_probe-<slug>.sh` (read-only AWS/k8s describe)             |
| ML            | `_probe-<slug>_eval.py`                                     |

## Why a probe and not console.log + re-run

- **Reproducible.** Re-runs give the same dump.
- **Documents the question.** Reading the file six months later reveals diagnostic intent.
- **Uses the test harness.** Same env, fixtures, and credentials as the failing assertion.
- **`console.log` / `print` in impl can lie** — wrong scope, wrong build, swallowed by the runner.

## Why delete before commit

- The probe is throwaway diagnostic, not a contract. Leaving it rots: the next refactor breaks the probe and a future agent must decide whether the probe was load-bearing.
- The fix lands as the commit. The probe is the scaffolding.

## Run shape

Probes need raw stdout. Wrap-style filters (RTK, lint reporters)
swallow it. Use the runner's raw / verbose mode:

| Stack      | Raw command                                                             |
| ---------- | ----------------------------------------------------------------------- | ------------------- |
| Playwright | `rtk proxy npx playwright test -g _probe-<slug>` (or `--reporter=list`) |
| vitest     | `pnpm exec vitest run _probe-<slug> --reporter=verbose`                 |
| Go         | `go test ./<pkg>/ -run _probe -v -count=1`                              |
| pytest     | `pytest -k _probe_<slug> -s`                                            |
| bats       | `bats --tap tests/_probe-<slug>.bats`                                   |
| dbt / SQL  | `psql ... -f _probe-<slug>.sql` (or dbt `compile + run-operation`)      |
| AWS / k8s  | `bash _probe-<slug>.sh 2>&1 \| tee /tmp/probe.txt`                      |

## Worked examples

### Web — `_probe-layout.behaviour.spec.ts`

Goal: understand why SidebarLayout demo collapsed to 222px.

```ts
test("measure sidebar-layout chain", async ({ page }) => {
  await page.goto("/#sidebar-layout", { waitUntil: "networkidle" });
  const dump = await page.evaluate(() => {
    const child =
      document.querySelector(".showcase__preview")?.firstElementChild;
    const cs = child ? getComputedStyle(child) : null;
    return {
      childWidth: child?.getBoundingClientRect().width,
      childMaxWidth: cs?.maxWidth,
      childMargin: cs?.margin,
    };
  });
  console.log("SIDEBAR-LAYOUT:", JSON.stringify(dump, null, 2));
});
```

Diagnosis: childWidth 222 + max-width 680px + margin auto-each-side = `min-content`. Fix: add `width: 100%`. Probe deleted.

### Backend — `_probe-idempotency_test.go`

Goal: understand why retry returned 409, not 200.

```go
func TestProbeIdempotency(t *testing.T) {
    body := `{"sku":"x","qty":1}`
    r1, _ := postOrder(t, "/v2/orders", body, "key-A")
    r2, _ := postOrder(t, "/v2/orders", body, "key-A")
    t.Logf("PROBE r1.status=%d r1.body=%s", r1.StatusCode, dumpBody(r1))
    t.Logf("PROBE r2.status=%d r2.body=%s", r2.StatusCode, dumpBody(r2))
    t.Logf("PROBE store keys=%v", store.Keys())
}
```

Output revealed: store had `key-A` after r1 but handler bypassed the lookup before r2. Fix: move lookup before validation. Probe deleted.

### CLI — `_probe-exit-code.bats`

Goal: understand why `--help` exited 64.

```bash
@test "probe: --help exit code" {
  run tool --help
  printf "PROBE status=%s\n" "$status" >&3
  printf "PROBE stdout-len=%s\n" "${#output}" >&3
  printf "PROBE first-line=%s\n" "$(echo "$output" | head -1)" >&3
}
```

Output: status=64, stdout empty. Diagnosis: `--help` hit usage-error branch because flag parser didn't know `--help`. Fix: register `--help` explicitly. Probe deleted.

### Data — `_probe-roundtrip.sql`

Goal: understand why fixture roundtrip differed by one row.

```sql
-- read-only: dumps row counts + checksum per partition
SELECT
  partition_date,
  count(*)            AS row_count,
  md5(string_agg(id::text, ',' ORDER BY id)) AS id_hash
FROM staging.events
GROUP BY 1
ORDER BY 1
LIMIT 50;
```

Diagnosis: one partition had a duplicate id from a re-run. Fix: dedupe in the staging step. Probe deleted.

### Infra — `_probe-iam.sh`

Goal: understand why pod can't read S3 bucket.

```bash
#!/usr/bin/env bash
set -euo pipefail
aws sts get-caller-identity
aws iam get-role --role-name "$ROLE"
aws iam list-attached-role-policies --role-name "$ROLE"
aws s3api get-bucket-policy --bucket "$BUCKET" || echo "no bucket policy"
kubectl describe sa "$SA" -n "$NS"
```

Diagnosis: trust policy missing `sts:AssumeRoleWithWebIdentity` for the IRSA condition. Fix: terraform module update. Probe deleted.

## Verify deletion before commit

```bash
git status --short | grep _probe   # should return empty
ls _probe-* 2>/dev/null              # should return empty
git log --oneline -20 | grep -i probe  # nothing committed
```

If a probe slips through, follow up immediately:

```bash
git rm _probe-*
git commit -m "chore: remove leftover probe"
```
