# 🚀 terraform-aws-eks-microservice-framework

A modular, production-ready Terraform framework for deploying Amazon EKS and running microservices (Fargate-backed). This repository provisions networking, IAM/IRSA, the EKS control plane, the AWS Load Balancer Controller, and a ready-to-use Grafana deployment with persistent storage managed by Amazon EFS so teams can stand up a repeatable EKS environment with durable monitoring storage.

---

## 🎯 Project / Goal / Who this is for

- Goal: Provide a repeatable, auditable baseline to provision an full EKS platform (Fargate profiles), CI-friendly Terraform modules, monitoring (Grafana with persistent EFS storage), and load balancing integration (ALB/NLB) using opinionated, modular Terraform.
- Who it's for: Infrastructure engineers, platform teams, and DevOps who need a production-oriented starting point for microservice deployments on AWS EKS with least-privilege IAM and clear operational procedures.
- Typical uses: PoC, staging, and production clusters where Terraform manages infrastructure and provides an out-of-the-box Grafana that persists dashboards and plugins across redeploys.

---

## ⚙️ Prerequisites (fresh machine)

Minimum recommended (tested): Terraform >= 1.6, AWS CLI v2, Helm >= 3.8, kubectl matching EKS control plane, Python >= 3.10.

Recommended packages (install on a fresh machine):

- System tools
  - git
  - make
  - curl, unzip
  - jq (JSON CLI helper)
  - yq (YAML CLI helper)
- Docker Desktop (macOS/Windows) or docker-ce (Linux) — optional for building images
- Terraform CLI (>= 1.6)
- AWS CLI v2
- kubectl
- eksctl (optional; useful for some dev workflows)
- Helm (>= 3.8)
- Python 3.10+ and pip
- pre-commit (pip install pre-commit)
- terraform-docs (used by the Makefile docs target)
- tflint (optional, recommended)
- kubeconform (optional — used by pre-commit for k8s manifest validation)
- Node.js + npm (optional; not required by the repo by default)
- Windows: we recommend WSL2 (Ubuntu) for consistent Makefile behavior

Installation examples

macOS (Homebrew)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew update
brew install git make terraform awscli kubectl helm jq yq python3 pre-commit terraform-docs tflint
# Install Docker Desktop from Docker site
```

Ubuntu (apt + distribution installers)
```bash
sudo apt update && sudo apt install -y git make unzip curl jq
# Install Terraform via HashiCorp apt repo
# Install AWS CLI v2 via bundled installer
# Install kubectl and helm per vendor instructions
python3 -m pip install --user pre-commit terraform-docs
```

Windows
- Use WSL2 (Ubuntu recommended) or install native tools (Terraform, AWS CLI, kubectl, Helm, Docker Desktop) using choco/winget.

---

## 🔐 AWS account and credentials

- Configure credentials:
  - `aws configure --profile <profile>` or set environment variables AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN, AWS_DEFAULT_REGION.
- Required permissions:
  - Create IAM roles/policies, EKS clusters, VPC resources, EC2 ENIs, ELB/ALB resources, EFS resources (if Terraform will create them), S3/DynamoDB for state.

---

## 🗂 Repository structure (relevant parts)

- `main.tf` — root orchestration of modules
- `variables.tf` — global inputs
- `output.tf` — exported outputs
- `backend.tf` — remote state backend config placeholder
- `alb_controller.tf` — AWS Load Balancer Controller Helm configuration
- `Makefile` — convenience workflow targets (init, plan, apply, destroy, etc.)
- `modules/*` — VPC, EKS, IAM, Grafana, etc.
- `env/<env>/terraform.tfvars` — environment-specific variables (create these)
- `k8s/*` — sample Kubernetes manifests
- `docs/*` — architecture, contributing, troubleshooting

---

## 📌 Grafana (ready-to-use) with EFS — primary feature

This repository includes a Grafana deployment wired to persistent storage managed by Amazon EFS.

Important behavioral note (DO NOT put EFS IDs in tfvars for the default workflow)
- The repo's Grafana/EFS integration is implemented so that Terraform creates and manages the EFS resources (file system, access point, mount targets) when the feature is enabled. After `terraform apply`, Terraform will output the created EFS IDs.
- You should **not** supply `efs_file_system_id` or `efs_access_point_id` in `env/<env>/terraform.tfvars` for the default workflow — those are produced by Terraform, not required as inputs.
- If you intentionally want to reuse an existing EFS created outside this repo, that is an advanced/custom workflow. In that case you must modify the module input surface to accept external EFS IDs (this repo currently manages EFS by default).

What is created (when enabled)
- aws_efs_file_system
- aws_efs_access_point
- mount targets in required subnets
- security group rules to allow NFS (TCP/2049) from the cluster ENIs

How to confirm
```bash
# after make apply / terraform apply
terraform state list | grep -i efs || true
terraform output efs_file_system_id
terraform output efs_access_point_id
terraform output -json | jq .
```

Security considerations
- EFS mount security groups must allow NFS (TCP/2049) from the cluster's ENIs or worker nodes.
- The module typically configures mount targets and SG rules for you when it creates EFS.

---

## 🔧 Backend (backend.hcl) — example & required fields

We use a remote S3 backend with optional DynamoDB locking. Create a local `backend.hcl` (do not commit) and supply it when running `terraform init`.

Example backend.hcl:
```hcl
bucket         = "terraform-state-bucket"
key            = "PATH/ENV/terraform.tfstate" # use per-environment path
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-state-lock"  # optional but recommended
acl            = "private"
role_arn       = "arn:aws:iam::123456789012:role/CI-Terraform-Role" # optional
```

Fields to populate:
- `bucket` — existing S3 bucket you control
- `key` — state file path; include ENV to separate environments
- `region` — S3 bucket region
- `encrypt` — true recommended
- `dynamodb_table` — for state locking (create table with PartitionKey "LockID")
- `role_arn` — optional IAM role to assume for Terraform runs

Usage:
```bash
terraform init -backend-config=backend.hcl
# or use Makefile: make init ENV=dev
```

---

## 🧾 Environment tfvars — location and required fields

The Makefile expects `env/$(ENV)/terraform.tfvars`. Copy `terraform.tfvars.example` to `env/dev/terraform.tfvars` and populate the values.

Minimum fields (from terraform.tfvars.example and module variables):
- `region` — AWS region (e.g., "us-east-1")
- `environment` — environment name (e.g., "dev")
- `owner` — owner tag / contact
- `identifier` — short prefix for resource names
- `endpoint_private_access` — true/false
- `endpoint_public_access` — true/false
- `public_access_cidrs` — list of CIDRs allowed for public API access
- `grafana_admin_user` — Grafana admin username
- `grafana_admin_password` — Grafana admin password (sensitive)

Note about EFS:
- Do NOT set `efs_file_system_id` or `efs_access_point_id` in `env` tfvars for the default behavior; Terraform creates and manages those resources. If you intentionally want to override with an external EFS, you must modify the module to accept external IDs (advanced workflow).

Other possible inputs you may need depending on your usage:
- `private_subnet_ids` — if using existing subnets
- `cluster_role_arn` — if pre-creating cluster IAM role
- `pod_execution_role_arn` — pod execution role for IRSA

Security:
- Never commit real credentials. Add `env/*` to `.gitignore` to avoid accidental commits.

---

## 🧭 Makefile: targets and explanations

High-level targets (see Makefile for exact behavior):

- `init`
  - Initializes Terraform in root and each module: `terraform init -upgrade`
  - Use after cloning & creating `backend.hcl` and `env/*/terraform.tfvars`.
  - Example: `make init ENV=dev`

- `plan`
  - Runs `terraform plan -var-file=env/$(ENV)/terraform.tfvars -out=plan-$(ENV).tfplan`
  - Guard: fails if TFVARS missing.
  - Example: `make plan ENV=dev`

- `apply`
  - Applies the previously created plan file: `terraform apply "plan-$(ENV).tfplan"`

- `destroy`
  - Runs `terraform destroy -var-file=env/$(ENV)/terraform.tfvars`
  - IMPORTANT: follow the resource removal ordering below to avoid "resource in use" errors.

- `validate`, `fmt`, `lint`, `docs`, `clean`, `help` — helper/quality targets (run `pre-commit`, `terraform fmt`, `terraform validate`, and generate module docs).

---

## ⚠️ Why delete Kubernetes resources (and ENIs) before `terraform destroy`

Terraform destroy can fail with "resource in use" when cloud resources (ENIs, target groups, PVC mounts) are still attached by Kubernetes controllers or pods.

Why:
- Kubernetes controllers (e.g., AWS Load Balancer Controller) create and manage AWS resources (target groups, listeners, NLB/ALB resources).
- Fargate pods mount ENIs. EFS mounts (via PVCs) remain until pods unmount PVCs. AWS blocks deletion of VPC/subnets/SGs/resources while attachments exist.

Recommended destroy ordering:
1. Delete application Kubernetes resources (Services, Ingresses, Deployments) so controllers detach and remove cloud resources:
```bash
kubectl delete -f k8s/service-hello-world.yaml
kubectl delete -f k8s/deployment-hello-world.yaml
# remove load balancer controller if required:
kubectl -n kube-system delete deploy aws-load-balancer-controller
```
2. Remove Grafana so PVCs unmount:
```bash
kubectl -n monitoring delete deploy grafana
helm -n monitoring uninstall grafana  # if installed by Helm
```
3. Wait for pods, PVCs, and ENIs to be removed:
```bash
kubectl get pods -A
kubectl get pvc -n monitoring
# In AWS console: EC2 -> Network Interfaces; ELB -> Target Groups
```
4. Run `make destroy ENV=dev`. If Terraform still errors:
```bash
terraform state list
# investigate blocking resource addresses
terraform state rm <address> # last resort
terraform destroy -auto-approve
```

Notes:
- The Makefile does not automatically delete K8s resources because that requires kubeconfig and is destructive. Manual deletion gives you control and prevents accidental data loss.

---

## 🧪 Full deploy (from fresh machine)

1. Clone:
```bash
git clone https://github.com/its-d/terraform-aws-eks-microservice-framework.git
cd terraform-aws-eks-microservice-framework
```

2. Create `backend.hcl` locally (example above), do NOT commit it.

3. Create environment tfvars:
```bash
mkdir -p env/dev
cp terraform.tfvars.example env/dev/terraform.tfvars
# Edit env/dev/terraform.tfvars and populate required fields (see section above)
```

4. Initialize Terraform:
```bash
terraform init -backend-config=backend.hcl
# or
make init ENV=dev
```

5. Plan:
```bash
make plan ENV=dev
```

6. Apply:
```bash
make apply ENV=dev
```

7. Grafana access:
- After apply, get Grafana service/endpoint via `kubectl get svc -n monitoring` or from Terraform outputs. Grafana is backed by the EFS created by Terraform (when enabled), so dashboards persist across pod restarts.

---

## Pre-commit & CI: what each step does, why it’s there, and how it works

Below are concise, copy/paste-ready explanations you can insert into your README describing the repository’s `.pre-commit-config.yaml` and `.github/workflows/ci.yml`. Each section lists the steps, what they do, and how they operate — plus the local commands you can run to mirror CI behavior.

---

### .pre-commit-config.yaml — purpose and hooks explained

Purpose: enforce consistent formatting, linting, and basic safety checks locally (before commits). This reduces CI failures and keeps the repo clean.

Key hooks configured and what they do
- General file hygiene (pre-commit hooks)
  - trailing-whitespace — removes any trailing whitespace from files.
  - end-of-file-fixer — ensures files end with a newline.
  - check-yaml — validates YAML syntax.
  - check-json — validates JSON syntax.
  - check-added-large-files — prevents accidentally staging very large files.
  - check-merge-conflict — detects unresolved merge conflict markers.

- Terraform helpers (pre-commit-terraform)
  - terraform_fmt — runs `terraform fmt -recursive` to format HCL.
  - terraform_validate — runs `terraform validate` to catch grammar/validation errors.
  - terraform_tflint — runs tflint for policy and best-practice checks.
  - terraform_docs — generates module docs (used by the Makefile/docs target).

- Python formatting & linting
  - black — formats Python files to a consistent style.
  - flake8 (+ plugins) — lints Python code; configured with recommended plugins and a 100-char max line length.

- YAML linting
  - yamllint — lints YAML and enforces configured rules (line-length disabled in config).

- Local/system hooks (repo: local)
  - kubeconform (system) — validates Kubernetes manifests in `k8s/*.yaml` against a specified Kubernetes version (strict validation).
  - add-apache-headers (addlicense) — enforces/updates Apache-2.0 license header on code files (tf, tfvars, yaml, py, sh).

How it works locally
- Install pre-commit and any system tools referenced by local hooks:
  - python -m pip install --upgrade pip
  - pip install pre-commit
  - Ensure system binaries used by local hooks are present (e.g., kubeconform, addlicense).
- Install the git hooks once in your repo:
  - pre-commit install
- Run all configured hooks against the whole repository (same as CI does):
  - pre-commit run --all-files

Notes / tips
- Some hooks call system binaries (kubeconform, addlicense). CI installs those into a `.bin` directory and adds it to PATH; replicate locally by installing the same tools (brew / apt / release downloads).
- Use `PCT_TFPATH` or configure your PATH if Terraform is not the default binary name in your environment (CI uses env var `PCT_TFPATH=terraform` when running pre-commit).

---

### .github/workflows/ci.yml — jobs, steps, and rationale

Purpose: run repository quality checks, Terraform validation, and plan generation on pushes and pull requests. The workflow is split into logical jobs so linting runs first and blocks invalid code from proceeding to Terraform validation/plan steps.

Top-level triggers and scope
- Runs on `push` and `pull_request` events limited to Terraform files, tfvars, the pre-commit config, scripts, and workflow files. This reduces unnecessary runs for unrelated changes.

Job: lint (Lint & Code Scan)
- Checkout repository
  - `actions/checkout` — fetches repo code so tools can scan files.
- Setup Python
  - `actions/setup-python` — ensures a reproducible Python runtime for pre-commit.
- Setup Terraform
  - `hashicorp/setup-terraform` — pins a Terraform CLI version for reproducible validation and `terraform fmt` behavior in CI.
- Setup TFLint
  - `terraform-linters/setup-tflint` — pins tflint to run policy/best-practice checks.
- Cache pre-commit
  - `actions/cache` caches pre-commit’s cache directory (`~/.cache/pre-commit`) keyed on `.pre-commit-config.yaml` so subsequent runs are faster.
- Install CLI tools (terraform-docs, kubeconform, addlicense)
  - CI downloads specific pinned releases (terraform-docs, kubeconform, addlicense) into a `.bin` folder and adds it to PATH so local-system hooks and doc generation can run. The script:
    - Looks up GitHub release assets by tag.
    - Downloads and extracts the linux/amd64 asset.
    - Moves the executable into `.bin` and makes it executable.
  - Rationale: local hooks reference binaries that are not Python packages; CI needs to provide those tools in PATH.
- Install pre-commit
  - `pip install pre-commit` so `pre-commit` is available in CI.
- Run pre-commit hooks
  - `pre-commit run --all-files` runs the full hook set (formatters, linters, kubeconform, addlicense). This enforces the same checks you run locally.

How to reproduce the lint job locally
1. Install the same pinned tools (terraform-docs, kubeconform, addlicense) or install equivalents to match CI versions.
2. pip install pre-commit.
3. Run: `pre-commit run --all-files`

Job: tf-validate (Terraform validation per environment)
- Depends on: lint (so only runs if pre-commit passed).
- Uses matrix of environment directories (e.g., `env/dev`) — the CI job runs `terraform fmt -check -recursive` and `terraform validate` for each env directory.
- Steps:
  - checkout
  - setup Terraform (same pinned CLI version)
  - `terraform fmt -check -recursive` — ensures formatting is correct (fails CI if not).
  - `terraform init -backend=false` (in the env directory) — initializes Terraform without remote backend so validation can run in CI without having access to state or secrets.
  - `terraform validate` — validates the configuration in each env directory.

Why init without backend?
- Running init with `-backend=false` avoids requiring S3/DynamoDB credentials and avoids writing state during CI. It lets Terraform load providers and validate configuration safely in CI.

How to run locally (per env)
```bash
cd env/dev
terraform init -backend=false
terraform validate
```

Job: tf-plan (Terraform plan for PRs)
- Runs only on pull requests and after `tf-validate`.
- Purpose: generate a Terraform plan file for reviewers to inspect. Because CI cannot access your remote backend safely, it runs `terraform init -backend=false` and `terraform plan -out=tfplan.bin` with flags that disable state refresh/locking:
  - `-input=false -refresh=false -lock=false`
- After planning the job runs `terraform show -no-color tfplan.bin > tfplan.txt` and uploads the plan as an artifact so reviewers can download and inspect the proposed changes.

Why plan with `-refresh=false -lock=false`?
- Avoids requiring access to remote state/DynamoDB locks and keeps CI plan generation read-only and non-blocking. It produces a plan based solely on configuration and local tfvars in `env/<env>/` (if present).

How to replicate the plan step locally (recommended only for dry-run / review)
```bash
cd env/dev
terraform init -backend=false
terraform plan -input=false -refresh=false -lock=false -out=tfplan.bin
terraform show -no-color tfplan.bin > tfplan.txt
```
Then inspect `tfplan.txt` or share it with reviewers.

Artifacts and caching
- CI uploads the generated plan (`tfplan.txt`) as an artifact for PR inspection.
- The pre-commit cache speeds up subsequent pre-commit runs on the same runner image / workflow.

Pinned versions and reproducibility
- CI pins tools (Terraform, tflint, terraform-docs, kubeconform, addlicense) to specific tags. Update these pins in the workflow script when you want to upgrade the tools. The workflow includes placeholders to add SHA256 checks for extra security after an initial verification run.

Secrets and tokens used
- `GITHUB_TOKEN` is used to access GitHub API (when looking up releases) and is injected by GitHub Actions automatically for CI jobs.
- CI does not require AWS credentials to run these validation steps because it initializes Terraform with `-backend=false` and avoids accessing remote state.

---

## Quick copy/paste snippet (for README)

You can paste this smaller snippet into your README to explain both files in one place:

```markdown
### Pre-commit & CI — what they run and why

- `.pre-commit-config.yaml` runs local checks before commits:
  - file hygiene (trim whitespace, add newline), YAML/JSON validation, large file checks.
  - Terraform formatting/validation/tflint and terraform-docs generation.
  - Python formatting (black) and linting (flake8 + plugins).
  - Kubernetes manifest validation via kubeconform and license header enforcement via addlicense.
  - Run locally:
    - `pip install pre-commit`
    - `pre-commit install`
    - `pre-commit run --all-files`

- `.github/workflows/ci.yml` runs CI checks on push/PR:
  - Lint job: checkout, setup Python & Terraform, install pinned CLI tools (terraform-docs, kubeconform, addlicense), install pre-commit, run `pre-commit run --all-files`.
  - tf-validate job: runs `terraform fmt -check`, `terraform init -backend=false`, `terraform validate` for env dirs.
  - tf-plan job (PRs): runs `terraform plan -out=tfplan.bin -input=false -refresh=false -lock=false`, converts to `tfplan.txt`, uploads as an artifact for reviewers.
  - CI avoids using remote backend (init uses `-backend=false`) so it doesn't need S3/DynamoDB credentials.
  - Locally reproduce CI validation with:
    - `terraform init -backend=false` and `terraform validate` in `env/<env>`; for plan: `terraform plan -input=false -refresh=false -lock=false -out=tfplan.bin` then `terraform show -no-color tfplan.bin > tfplan.txt`.
```

---

## 📚 Documentation

Expanded docs live in `docs/`:
- `docs/architecture.md` — architecture overview and data flow
- `docs/contributing.md` — contribution and testing workflow
- `docs/troubleshooting.md` — extended troubleshooting (EFS, ENIs, locks, etc.)

---

## ⚖️ License

Apache License 2.0 — see LICENSE.

---

## 👤 Author

**Darian Lee** — Infrastructure Engineer & Cloud Consultant
