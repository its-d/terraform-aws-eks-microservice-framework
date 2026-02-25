# repo-breakdown.md
**Repository:** terraform-aws-eks-microservice-framework
**Generated:** 2025-02-24
**Analyzed by:** /analyze command

---

## 1. Repository Summary

**What it does:** A Terraform framework that provisions a production-ready Amazon EKS platform on AWS. It creates a VPC with public/private subnets, IAM roles for the EKS control plane and Fargate pod execution, an EKS cluster with Fargate profiles, IAM Roles for Service Accounts (IRSA) for the AWS Load Balancer Controller, deploys the AWS Load Balancer Controller via Helm, and deploys Grafana for monitoring. The framework is designed for teams that need a repeatable, auditable baseline to run microservices on EKS with minimal operational overhead.

**Languages:** HCL (Terraform), YAML (CI, pre-commit, docs), Makefile (shell), Python (pre-commit dependencies), JSON (IAM policies).

**Dependencies:** Terraform >= 1.5.0, AWS provider ~> 5.95, Helm ~> 2.13, Kubernetes ~> 2.29, null ~> 3.2, terraform-aws-modules/vpc/aws ~> 5.8, terraform-aws-modules/eks/aws ~> 20.0, pre-commit with terraform-docs, tflint, black, flake8, yamllint, kubeconform, addlicense.

**Structure:**
- **Root:** `main.tf` (orchestration), `variables.tf`, `outputs.tf`, `alb_controller.tf`, `terraform.tfvars.example`, `Makefile`, `backend.hcl.example`
- **modules/vpc:** VPC with public/private subnets, NAT, outputs for subnet IDs
- **modules/eks:** EKS cluster, Fargate profiles, CoreDNS config
- **modules/iam:** EKS cluster role, pod execution role
- **modules/iam_irsa:** IRSA role for AWS Load Balancer Controller
- **modules/grafana:** Helm release for Grafana, Secrets Manager integration
- **env/dev|prod|test:** Environment dirs with `.gitkeep` only (tfvars/backend created by user)
- **docs/:** architecture, contributing, troubleshooting
- **.github/workflows/ci.yml:** Lint, tf-validate, tf-plan

**Overall assessment:** The codebase is well-organized and follows Terraform best practices. License headers, pre-commit, and modular structure are in place. However: CI runs Terraform validate/plan from `env/dev` which only contains `.gitkeep`—no Terraform config there, so the workflow would fail or validate nothing; `public_access_cidrs` defaults to `["0.0.0.0/0"]` in root and EKS module (security risk if `make _confirm_ip` is skipped); VPC module hardcodes `us-east-1a`/`us-east-1b` and CIDR; Grafana README references `grafana_admin_user`/`grafana_admin_password` but the module uses `grafana_user_arn`/`grafana_pwd_arn`; CHANGELOG claims "Grafana that persists dashboards" but `persistence.enabled = false`. No Terraform test files (`.tftest.hcl`) or Terratest in the repomix. The framework is production-oriented but has gaps in CI configuration, security defaults, and test coverage.

---

## 2. Test Coverage

### Currently Tested
- **pre-commit hooks:** `terraform_fmt`, `terraform_validate`, `terraform_tflint`, `terraform_docs` run against the repo
- **CI lint job:** Runs pre-commit on all files
- **CI tf-validate job:** Runs `terraform init -backend=false` and `terraform validate` from `env/dev` (but env/dev has no Terraform config—only `.gitkeep`)
- **CI tf-plan job:** Runs `terraform plan` from `env/dev` (same issue)

### Missing Coverage — Action Required
- **variables.tf** — No tests
- **main.tf** — No tests
- **outputs.tf** — No tests
- **alb_controller.tf** — No tests
- **Makefile** — No automated tests for targets
- **modules/vpc/main.tf** — No tests
- **modules/vpc/outputs.tf** — No tests
- **modules/vpc/variables.tf** — No tests
- **modules/eks/main.tf** — No tests
- **modules/eks/outputs.tf** — No tests
- **modules/eks/variables.tf** — No tests
- **modules/iam/main.tf** — No tests
- **modules/iam/outputs.tf** — No tests
- **modules/iam/variables.tf** — No tests
- **modules/iam_irsa/main.tf** — No tests
- **modules/iam_irsa/outputs.tf** — No tests
- **modules/iam_irsa/variables.tf** — No tests
- **modules/grafana/main.tf** — No tests
- **modules/grafana/outputs.tf** — No tests
- **modules/grafana/variables.tf** — No tests
- **.github/workflows/ci.yml** — No workflow tests

### Partial Coverage — Needs Improvement
- **CI tf-validate/tf-plan:** Run from `env/dev` which has no Terraform configuration; effectively no validation of root config. Should run from repo root with `-var-file=terraform.tfvars.example` or similar.

---

## 3. Vulnerabilities

### Critical
None identified.

### High
- **variables.tf line 2335** — `public_access_cidrs` defaults to `["0.0.0.0/0"]`. If a user skips `make _confirm_ip` or forgets to set this in tfvars, the EKS API endpoint is exposed to the entire internet. **Exploit:** Attacker scans for publicly reachable EKS endpoints; gains API access if IAM/RBAC is misconfigured. **Fix:** Remove the default; require callers to explicitly set CIDRs (e.g., via tfvars or `make _confirm_ip`).
- **modules/eks/variables.tf line 2346** — Same `public_access_cidrs` default `["0.0.0.0/0"]`. **Fix:** Remove default; pass through from root or require explicit value.

### Medium
- **modules/iam_irsa/policies/aws_load_balancer_controller_iam_policy.json** — All statements use `Resource: "*"`. This is required by the AWS Load Balancer Controller to manage ELB/EC2/ACM across the account; AWS does not support resource-level scoping for these actions. **Exploit:** If the IRSA role is compromised, attacker has broad ELB/EC2/ACM permissions. **Fix:** Document as accepted risk in README; consider scoping if AWS adds support in future.
- **Grafana module (modules/grafana/main.tf)** — `adminUser` and `adminPassword` from Secrets Manager are passed into Helm and stored in Terraform state as sensitive. **Exploit:** State file exposure (e.g., S3 bucket misconfiguration) could leak credentials. **Fix:** Use remote backend with encryption, restrict state access via IAM, document in contributing.md.

### Low
- **.gitignore** — `*.hcl` excludes `backend.hcl` and `env/*/backend.hcl`, which is correct. `backend.hcl.example` is not excluded and contains no secrets. **Fix:** Add comment in .gitignore that `*.hcl` intentionally excludes backend config files to prevent accidental commit.
- **CI install script (.github/workflows/ci.yml)** — Downloads terraform-docs, kubeconform, addlicense without SHA256 verification. **Exploit:** Supply-chain attack if GitHub/CDN is compromised. **Fix:** Add SHA256 pins for downloaded binaries where checksums are published.

---

## 4. Code Quality

### Dead Code
- **modules/iam/outputs.tf lines 18–20** — Duplicate comment block "IRSA role ARN for the AWS Load Balancer Controller" appears twice; remove the duplicate.

### Complexity Issues
- **Makefile** — `_force_k8s_purge` (lines ~2900–2923) and `_aws_net_purge` (lines ~2926–2949) are long inline shell scripts. Consider extracting to `scripts/` for readability.
- **Makefile** — `_state_rm_vpc` and `_force_delete_vpc` are complex; could be scripts.
- **modules/grafana/main.tf** — `helm_release.grafana` block is ~120 lines with many `set` blocks; acceptable for Helm but could use `values` file for maintainability.

### Best Practice Violations
- **Makefile line 2975** — `@echo "..."` followed by `\` and `@set` on next line; missing newline after echo causes `@set` to be interpreted as part of the echo. **Fix:** Add newline: `@echo "..."` then newline, then `@set`.
- **variables.tf / modules/eks/variables.tf** — `public_access_cidrs` default `["0.0.0.0/0"]` violates principle of least privilege.
- **modules/iam/main.tf** — IAM role names `eks_cluster_role` and `eks_pod_execution_role` are not prefixed with identifier; can cause conflicts in multi-tenant or multi-environment AWS accounts. **Fix:** Use `"${var.identifier}-eks-cluster-role"` pattern.

### Documentation Gaps
- **modules/grafana/README.md** — References `grafana_admin_user` and `grafana_admin_password` as inputs; module actually uses `grafana_user_arn` and `grafana_pwd_arn` (Secrets Manager ARNs). **Fix:** Update README to match module interface.
- **CHANGELOG.md** — Claims "Grafana that persists dashboards and plugins across redeploys" (README) and "Grafana with ephemeral Storage" (CHANGELOG v0.1.0); `persistence.enabled = false` in Grafana module. **Fix:** Align CHANGELOG/README with actual behavior (ephemeral).
- **README.md** — CI section says "CI initializes Terraform with -backend=false"; does not clarify that tf-validate/tf-plan run from `env/dev` which has no Terraform config. **Fix:** Document that CI should run from root or that env dirs need symlinks/wrappers.

---

## 5. Improvements

### Quick Wins
- **Remove `public_access_cidrs` default** in variables.tf and modules/eks/variables.tf — Reduces accidental exposure; 5 min.
- **Fix Makefile `_force_delete_vpc`** — Add newline between echo and set; 2 min.
- **Update modules/grafana/README.md** — Change `grafana_admin_user`/`grafana_admin_password` to `grafana_user_arn`/`grafana_pwd_arn`; 5 min.
- **Remove duplicate comment** in modules/iam/outputs.tf; 1 min.
- **Add `monitoring_namespace` output** to modules/grafana/outputs.tf if consumers need it; 2 min.
- **Add .gitignore comment** for `*.hcl` explaining backend exclusion; 1 min.

### Medium Effort
- **Fix CI to run from root** — Change tf-validate and tf-plan to use repo root with `-var-file=terraform.tfvars.example` and `-backend=false`; requires updating workflow; 30 min.
- **Parameterize VPC** — Add `azs` and `cidr` variables to modules/vpc; 20 min.
- **Add identifier prefix to IAM roles** — Update modules/iam to use `"${var.identifier}-eks-cluster-role"`; 15 min.
- **Add Terraform `.tftest.hcl`** for VPC, IAM, IAM_IRSA, EKS modules (plan-only); 1–2 hours.
- **Document Grafana state sensitivity** in docs/contributing.md; 10 min.
- **Document IAM `Resource: "*"`** as accepted risk in modules/iam_irsa/README.md; 5 min.

### Large Effort
- **Extract Makefile scripts** — Move `_force_k8s_purge`, `_aws_net_purge`, `_state_rm_vpc`, `_force_delete_vpc` to scripts/; update Makefile to call them; 1–2 hours.
- **Add Terratest** — Integration tests that provision/destroy in a test AWS account; significant setup; 4+ hours.
- **Add root-level .tftest.hcl** — Plan-only test for full stack; may fail without AWS; 2–3 hours.
- **CI matrix for multi-env** — Validate dev/test/prod; 30 min.

---

## 6. Todo Checklist

### 🔴 Security
- [x] [HIGH] Remove default `["0.0.0.0/0"]` from `public_access_cidrs` in variables.tf — require explicit CIDRs #security ✅
- [x] [HIGH] Remove default `["0.0.0.0/0"]` from `public_access_cidrs` in modules/eks/variables.tf — require explicit CIDRs #security ✅
- [x] [MEDIUM] Document IAM policy `Resource: "*"` as accepted risk in modules/iam_irsa/README.md #security ✅
- [x] [MEDIUM] Document Grafana state sensitivity (remote backend, encryption, access control) in docs/contributing.md #security ✅
- [x] [LOW] Add .gitignore comment that `*.hcl` excludes backend.hcl to prevent accidental commit #security ✅
- [x] [LOW] Add SHA256 verification for terraform-docs, addlicense, kubeconform in CI install script where checksums are published #security ✅

### 🧪 Tests
- [x] [MISSING] Write Terraform .tftest.hcl for modules/vpc — plan-only run with variables #tests ✅
- [x] [MISSING] Write Terraform .tftest.hcl for modules/iam — plan-only run #tests ✅
- [x] [MISSING] Write Terraform .tftest.hcl for modules/iam_irsa — plan-only run (requires OIDC mocks or skip) #tests ✅
- [x] [MISSING] Write Terraform .tftest.hcl for modules/eks — plan-only run #tests ✅
- [~] [MISSING] Write Terraform .tftest.hcl for modules/grafana — plan-only run (requires Secrets Manager; may skip in CI) #tests ❌ BLOCKED

  **Why it was blocked:** The Grafana module uses `data "aws_secretsmanager_secret_version"` to fetch admin credentials. Terraform plan requires these data sources to resolve, which needs real AWS credentials and existing Secrets Manager secrets. There is no way to mock or skip data source fetches during plan.
  **What to do:** (1) Create a test AWS account or use a dedicated test secret ARN. (2) Add `grafana.tftest.hcl` with variables pointing to that secret ARN. (3) Run `terraform test` in CI only when AWS credentials and the secret exist (e.g., in a separate workflow with secrets). Alternatively, exclude Grafana from `make test` (already done) and document that Grafana is tested manually.
- [x] [MISSING] Add root-level .tftest.hcl or CI job that validates root config with terraform.tfvars.example #tests ✅
- [x] [PARTIAL] Fix CI tf-validate and tf-plan to run from repo root with -var-file=terraform.tfvars.example — env/dev has no Terraform config #tests ✅

### 🔧 Code Quality
- [x] [DEAD CODE] Remove duplicate comment "IRSA role ARN for the AWS Load Balancer Controller" in modules/iam/outputs.tf lines 18–20 #quality ✅
- [x] [BEST PRACTICE] Add newline between `@echo` and `@set` in Makefile _force_delete_vpc target (line ~2975) #quality ✅
- [x] [BEST PRACTICE] Add identifier prefix to IAM role names in modules/iam/main.tf (eks_cluster_role, eks_pod_execution_role) #quality ✅
- [x] [DOCS] Update modules/grafana/README.md to use grafana_user_arn and grafana_pwd_arn instead of grafana_admin_user/grafana_admin_password #quality ✅
- [x] [DOCS] Correct CHANGELOG/README to state Grafana uses ephemeral storage (persistence.enabled = false) #quality ✅
- [x] [DOCS] Clarify CI working directory (root vs env/dev) in README #quality ✅

### 💡 Improvements
- [x] [QUICK WIN] Add monitoring_namespace output to modules/grafana/outputs.tf #improvement ✅
- [x] [QUICK WIN] Parameterize VPC azs and cidr in modules/vpc/variables.tf #improvement ✅
- [x] [MEDIUM EFFORT] Fix CI to run tf-validate and tf-plan from repo root #improvement ✅
- [x] [MEDIUM EFFORT] Add Terraform .tftest.hcl tests for VPC, IAM, IAM_IRSA, EKS modules #improvement ✅
- [x] [LARGE EFFORT] Extract Makefile inline scripts (_force_k8s_purge, _aws_net_purge, etc.) to scripts/ #improvement ✅

---
*Generated by /analyze — run /work-todo to execute all items automatically, or run /fix-security, /fix-tests, /fix-quality, and /fix-improvements individually.*

---

## 7. Work-Todo Execution Summary
**Completed:** 2025-02-24

| Result | Count |
|--------|-------|
| ✅ Completed | 23 |
| ❌ Blocked | 1 |
| ⏭ Skipped | 0 |
| **Total** | 24 |

### Blocked Items Summary
- **Grafana .tftest.hcl:** The Grafana module uses `data "aws_secretsmanager_secret_version"` to fetch admin credentials. Terraform plan requires these data sources to resolve, which needs real AWS credentials and existing Secrets Manager secrets. There is no way to mock or skip data source fetches during plan. **What to do:** (1) Create a test AWS account or use a dedicated test secret ARN. (2) Add `grafana.tftest.hcl` with variables pointing to that secret ARN. (3) Run `terraform test` in CI only when AWS credentials and the secret exist. Alternatively, exclude Grafana from `make test` (already done) and document that Grafana is tested manually.

### Skipped Items Summary
None.
