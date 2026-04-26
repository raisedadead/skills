# Lens — Infrastructure / IaC

For declarative infrastructure — Terraform / Pulumi / CDK / Helm /
Kustomize / Ansible / k8s manifests — where `plan` IS the test
and drift is the enemy.

## Surface vocabulary

- **Unit:** resource (`aws_s3_bucket.foo`, `kubernetes_deployment.api`).
- **Output:** plan diff (`terraform plan`, `pulumi preview`, `helm diff`), state export, IAM policy, manifest set.
- **Contract:** plan-only diff against frozen baseline + cost estimate (optional) + policy compliance + drift = 0.

## Specific gates (meta-gate extensions)

- **Plan baseline freeze.** `terraform plan -out=tfplan && terraform show tfplan > baseline.txt`. Committed; CI re-plans, diffs against baseline. Surprise diff → fail.
- **Provider / module pin.** `versions.tf` declares `version = "~> X.Y"` (or exact). Meta-gate regex on `versions.tf` floor.
- **No `terraform import` in apply path.** Imports are one-shot, not idempotent. → meta-gate greps `terraform import` in CI scripts.
- **No `local-exec` provisioners in production modules.** They break idempotency. → meta-gate.
- **Resource naming convention.** All resources follow `<env>-<svc>-<role>` regex. Meta-gate walks `.tf` files.
- **Tag / label set.** Required tags (`env`, `owner`, `cost-center`) on every taggable resource. Meta-gate on `tags = {}` blocks.
- **No public S3 / blob.** Bucket ACL meta-gate denies `public-*`. Same for k8s NetworkPolicy.
- **IAM least-privilege.** No `Action: "*"` / `Resource: "*"` together; meta-gate on policy JSON.
- **k8s manifest pinning.** All images pinned by digest (`@sha256:...`), not tag. Meta-gate.
- **Helm values schema.** `values.schema.json` exists; meta-gate validates `values.yaml` against it.

## Output rebaseline specifics

| Step               | Command                                                                |
| ------------------ | ---------------------------------------------------------------------- |
| Build / compile    | `terraform init` / `pulumi up --preview`                               |
| Plan-only run      | `terraform plan -out=tfplan` / `helm template`                         |
| Unbaselined diff   | `terraform show tfplan > current.txt && diff baseline.txt current.txt` |
| Read failures      | resources added / changed / destroyed listed                           |
| Accept             | `cp current.txt baseline.txt`                                          |
| Apply (NEVER auto) | user runs `terraform apply tfplan` themselves                          |

Goldens: `baseline.txt` (plan diff), `policy/` (compiled OPA / Sentinel rules).

## Probe specifics

- File: `_probe-<slug>.sh` (read-only AWS / k8s describe)
- Runner: `bash _probe-<slug>.sh 2>&1 | tee /tmp/probe.txt`
- Dump shape: `aws sts get-caller-identity`, `aws iam get-role`, `aws iam list-attached-role-policies`, `kubectl describe sa`, `kubectl get pod -o yaml`.
- Common dump targets: trust policy, IRSA condition, security-group ingress, k8s RBAC bindings, network-policy match.

## Stack footguns

- **`terraform apply` between plan and accept.** Plan goes stale; second apply diverges. → always use `terraform apply tfplan` against the saved plan.
- **State drift from console clicks.** Operator changed something in AWS console; next plan shows diff. → run `terraform refresh` deliberately; never on autopilot. File a finding.
- **Module + nested module variable shadowing.** Variable named `name` in two places → wrong value propagates. → namespace every variable.
- **`count` vs `for_each` migration.** Switching loses state. → use `terraform state mv` explicitly; meta-gate on this in PR review.
- **Cycle detection masked by `depends_on`.** Real cycle hidden. → meta-gate on excessive `depends_on` (heuristic).
- **Plan green, apply fails on quota.** No way to know without applying. → quota check probe before plan.
- **`null` vs `""` drift in TF.** Attribute "fixed" by setting empty string; provider treats as different. → choose one convention; meta-gate.
- **k8s rolling update with `terminationGracePeriodSeconds: 30` + 2-min health-check.** Pods killed before ready. → assert grace > startup floor.
- **Helm subchart override silently ignored.** Override path wrong (`subchart.foo` vs `foo`). → meta-gate via `helm template` diff before merge.
- **Secret in `tfvars` committed.** → pre-commit hook + meta-gate (denylist patterns).

## Phase shape hint

Typical sub-phases for an infra phase:

- P0 — plan baseline freeze + drift detect setup
- P1 — meta-gates (pin, tag, policy, naming, RBAC)
- P2 — module work (per-module TDD round = plan-RED → fix → plan-GREEN → freeze)
- P3 — staging soak + drift verify
- P4 — rollout plan (per env order, rollback procedure)
- P5 — operator handoff + closeout (runbook export if approved)
