# 🚀 terraform-aws-eks-microservice-framework

A modular, production-ready Terraform framework for deploying Amazon EKS and running microservices (Fargate-backed). This repository provisions networking, IAM/IRSA, the EKS control plane, the AWS Load Balancer Controller, and a ready-to-use Grafana deployment with persistent storage managed by Amazon EFS so teams can stand up a repeatable EKS environment with durable monitoring storage.

---

## 🎯 Project / Goal / Who this is for

- Goal: Provide a repeatable, auditable baseline to provision a full EKS platform (Fargate profiles), CI-friendly Terraform modules, monitoring (Grafana with persistent EFS storage), and load balancing integration (ALB/NLB) using opinionated, modular Terraform.
- Who it's for: Infrastructure engineers, platform teams, and DevOps who need a production-oriented starting point for microservice deployments on AWS EKS with least-privilege IAM and clear operational procedures.
- Typical uses: PoC, staging, and production clusters where Terraform manages infrastructure and provides an out-of-the-box Grafana that persists dashboards and plugins across redeploys.

---

## ⚙️ Prerequisites (fresh machine)

Minimum recommended (tested): Terraform >= 1.6 (CI pins 1.9.x — see CI workflow), AWS CLI v2, Helm >= 3.8, kubectl matching EKS control plane, Python >= 3.10.

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
- kubectl (useful for manual inspection; not required for standard Makefile-driven deploy)
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

## 🔧 First-time backend / bootstrap (recommended)

You can create the backend resources manually or with a small helper. Example Terraform snippet to create a state S3 bucket & DynamoDB table (run in a separate one-off bootstrap workspace) can live in `scripts/bootstrap-backend.example.tf` (suggestion). If you prefer commands, create the S3 bucket and DynamoDB table via AWS console / CLI.

Example backend.hcl (local file; do NOT commit):
```hcl
bucket         = "my-terraform-state-bucket"
key            = "terraform-aws-eks-microservice-framework/ENV/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "my-terraform-state-locks"
```

Usage:
```bash
make init
```

---

## Quick first-time checklist (do these before running apply)
1. Create remote state artifacts (S3 bucket + DynamoDB table) or have a backend.hcl ready:
   - S3 bucket (private) for Terraform state
   - DynamoDB table with partition key "LockID" for state locking (recommended)
2. Copy example tfvars and populate required fields:
   - `cp terraform.tfvars.example env/dev/terraform.tfvars`
   - Edit `env/dev/terraform.tfvars` (see "env tfvars" below)
3. Confirm your public IP with the repository helper (REQUIRED — see "_confirm_ip"):
   - `make _confirm_ip`
   - This ensures `public_access_cidrs` in your environment tfvars is set to the IP that should be permitted to access the EKS API (prevents accidentally opening public access).
4. Ensure you have the minimum toolchain installed (Terraform, AWS CLI, kubectl, Helm, Python + pre-commit).
5. Run: `make init` (or `terraform init -backend-config=backend.hcl`) and ensure init succeeds.
6. Run: `make plan` then `make apply`.

Tip: Use a feature branch and open a PR so CI validates formatting and terraform validation before merging to main.

---

## 🔒 EKS API Access — Why IP Configuration Matters

Terraform (and Helm) must reach the EKS API endpoint during `apply`.
If your public IP is not listed in `public_access_cidrs`, you’ll see TLS handshake
or timeout errors even though the cluster exists.

**Set your IP safely:**
```bash
make _confirm_ip
```
This command detects your current public IPv4 address and injects it into your environment
tfvars file:

```hcl
public_access_cidrs = ["<your-ip>/32"]
```

**Why it’s required**
- Prevents failed `kubectl` or `helm` calls that depend on API access.
- Avoids accidentally exposing the cluster to the internet (`0.0.0.0/0`).
- Keeps your deployments reproducible when switching networks or VPNs.

**If skipped**
- `terraform apply` may hang or fail with:
  ```
  could not get current server API group list:
  net/http: TLS handshake timeout
  ```
- Helm charts and Kubernetes resources will not deploy.
- Destroy operations may partially complete and leave residual resources.

**In automation**
- Once you move apply into CI/CD (inside AWS or GitOps), you can disable public access entirely
  and remove the `_confirm_ip` step.

---

## _confirm_ip — confirm your IP before planning/deploying (REQUIRED)

Why this exists
- By default the repo can enable public access to the EKS API (controlled by `public_access_cidrs` TF variables). To protect the cluster and reduce mistakes when people run the plan/apply, we require a short confirmation step that captures and/or validates your public IP and writes it into the environment tfvars (or instructs you how to do it).
- Running `_confirm_ip` prevents accidental wide-open public access and ensures the Terraform plan uses the intended CIDR (your office/home IP) for API access.

What `make _confirm_ip` does (recommended implementation behavior)
- Detects your current public IPv4 address using a safe external service (e.g., `https://checkip.amazonaws.com`).
- Prints the detected IP and asks you to confirm ("Is this the correct IP to allow? (Y/n)").
- On yes:
  - It updates `env/$(ENV)/terraform.tfvars` (or creates it from example) to set `public_access_cidrs = ["<your_ip>/32"]` (or updates equivalent field).
- On no:
  - It prints instructions and a single command you can run to set the desired CIDR manually.
  - It aborts without touching your tfvars so you can take manual action.

How to run
- Example (for dev environment):
```bash
# detect / confirm your IP and update env/dev/terraform.tfvars
make _confirm_ip
```

Manual fallback
- If you prefer to edit manually, open `env/dev/terraform.tfvars` and set:
```hcl
public_access_cidrs = ["203.0.113.45/32"]  # replace with your confirmed IP/CIDR
```

Security notes
- Confirming your IP reduces accidental exposure, but do not rely on IP-based access as your only control. Use IAM, RBAC, and private endpoints where appropriate.
- If you have a dynamic IP (e.g., home ISP), prefer using a VPN, bastion host, or private API endpoint instead of opening a public CIDR to the cluster.

Enforcement guidance
- We recommend treating `_confirm_ip` as mandatory in your onboarding checklist and adding a CI/PR checklist item that the contributor ran it locally before creating a plan PR.

---

## 🧾 Environment tfvars — location and required fields

The Makefile expects `env/$(ENV)/terraform.tfvars`. Copy `terraform.tfvars.example` to `env/dev/terraform.tfvars` and populate the values.

Minimum fields (from terraform.tfvars.example and module variables):
- `region` — AWS region (e.g., "us-east-1")
- `environment` — environment name (e.g., "dev")
- `owner` — owner tag / contact
- `identifier` — short prefix for resource names
- `public_access_cidrs` — list of CIDRs allowed for public API access
- `grafana_admin_user` — Grafana admin username
- `grafana_admin_password` — Grafana admin password (sensitive)

Note about EFS:
- Do NOT set `efs_file_system_id` or `efs_access_point_id` in `env` tfvars for the default behavior. The storage module creates EFS and the root module wires its outputs into grafana.

Other possible inputs you may need depending on your usage:
- `private_subnet_ids` — if using existing subnets
- `cluster_role_arn` — if pre-creating cluster IAM role
- `pod_execution_role_arn` — pod execution role for IRSA

Security:
- Never commit real credentials. Add `env/*` to `.gitignore` to avoid accidental commits.

Secrets & recommended pattern
- For production / public usage, store sensitive values (Grafana admin password, etc.) in SSM Parameter Store or Secrets Manager and reference them in Terraform (or inject them via CI secrets). Example pattern:
  - Put secret into SSM: `aws ssm put-parameter --name "/project/dev/grafana_admin_password" --type "SecureString" --value "<SECRET>"`
  - Refer to SSM via Terraform data source `aws_ssm_parameter` with `with_decryption = true`.

---

## 📌 Grafana (ready-to-use) with EFS — primary feature

This repository includes a Grafana deployment wired to persistent storage managed by the storage module (EFS) and exposed to Grafana via PersistentVolume/PersistentVolumeClaim.

Important behavioral note (default flow)
- The `modules/storage` module creates the EFS file system, mount targets, and access point when deployed. The root `main.tf` instantiates `module.storage` and passes its outputs to `module.grafana`.
- Do NOT set `efs_file_system_id` or `efs_access_point_id` in `env/<env>/terraform.tfvars` for the default workflow — these IDs are produced by Terraform and exposed as module outputs.
- If you intentionally want to reuse an external EFS created outside this repo, that is an advanced workflow: you must update module usage or supply optional variables to accept external IDs.

What is created (when storage is enabled)
- `aws_efs_file_system`
- `aws_efs_access_point`
- `aws_efs_mount_target` in required subnets
- security group(s) to allow NFS (TCP/2049) from the cluster ENIs

How to confirm (after apply)
```bash
terraform output efs_file_system_id
terraform output efs_access_point_id
terraform output -json | jq .
# or inspect state
terraform state list | grep -i efs || true
```

Grafana access
- After apply, retrieve Grafana information using the Makefile convenience targets or Terraform outputs:
  - `make outputs` (recommended — prints cluster and EFS outputs if available)
- The repository intentionally avoids baking manual kubectl instructions into the standard deploy path — the platform deploys via Terraform (init/plan/apply) and application manifests should be managed by CI/GitOps or developer workflows outside of this Makefile-driven infra flow.

---

## 🗂 Repository structure (relevant parts)

- `main.tf` — root orchestration of modules
- `variables.tf` — global inputs
- `output.tf` — exported outputs
- `alb_controller.tf` — AWS Load Balancer Controller Helm configuration
- `Makefile` — convenience workflow targets (init, plan, apply, destroy, etc.)
- `modules/*` — VPC, EKS, IAM, storage, Grafana, app, etc.
- `env/<env>/terraform.tfvars` — environment-specific variables (create these)
- `env/<env>/backend.hcl` - environment-specific backend configuration (create this)
- `docs/*` — architecture, contributing, troubleshooting
- `.github/workflows/ci.yml` — CI pipeline (pre-commit, terraform validate, plan artifacts)

---

## 🧭 Makefile: targets and explanations

High-level targets (see Makefile for exact behavior):

- `init`
  - Initializes Terraform in root and each module: `terraform init -upgrade`
  - Use after cloning & creating `env/*/backend.hcl` and `env/*/terraform.tfvars`.
  - Example: `make init`

- `plan`
  - Runs `terraform plan -var-file=env/$(ENV)/terraform.tfvars -out=plan-$(ENV).tfplan`
  - Guard: fails if TFVARS missing.
  - Example: `make plan`

- `apply`
  - Applies the previously created plan file: `terraform apply "plan-$(ENV).tfplan"`

- `destroy`
  - Runs `terraform destroy -var-file=env/$(ENV)/terraform.tfvars`
  - IMPORTANT: remove or ensure in-cluster resources (Helm releases, GitOps-managed resources, application workloads) are torn down before running destroy to avoid "resource in use" errors.

- `validate`, `fmt`, `lint`, `docs`, `clean`, `help` — helper/quality targets (run `pre-commit`, `terraform fmt`, `terraform validate`, and generate module docs).

- `grafana-url`
  - Gets the Grafana endpoint URL (if the Makefile/terraform outputs are configured to provide it)

Recommended additions (suggested changes you can add to the Makefile)
- `make outputs` — convenience target to show key outputs:
```makefile
outputs:
	@echo "Cluster name: $$(terraform output -raw cluster_name 2>/dev/null || echo '<not set>')"
	@echo "Grafana EFS FS ID: $$(terraform output -raw efs_file_system_id 2>/dev/null || echo '<not set>')"
	@echo "Grafana EFS AP ID: $$(terraform output -raw efs_access_point_id 2>/dev/null || echo '<not set>')"
```

---

## ⚠️ Why ensure in-cluster resources are removed before `terraform destroy`

Terraform destroy can fail with "resource in use" when cloud resources (ENIs, target groups, PVC mounts) are still attached by Kubernetes controllers or pods.

Why:
- Kubernetes controllers (e.g., AWS Load Balancer Controller) create and manage AWS resources (target groups, listeners, NLB/ALB resources).
- Fargate pods mount ENIs. EFS mounts (via PVCs) remain until pods unmount PVCs. AWS blocks deletion of VPC/subnets/SGs/resources while attachments exist.

Recommended destroy ordering:
1. Ensure application workloads, Helm releases, or GitOps-managed resources are removed from the cluster (use your deployment tooling or Helm/GitOps processes).
2. Remove Grafana Helm release or application Helm charts so PVCs unmount.
3. Wait for pods, PVCs, and ENIs to be removed (verify in the AWS Console and/or Kubernetes dashboard).
4. Run `make destroy`. If Terraform still errors, inspect state and remove blocking resources cautiously.

Notes:
- The Makefile intentionally does not perform destructive in-cluster deletions because that requires kubeconfig and is often organization-specific. Use your standard application lifecycle tooling to remove in-cluster resources before running Terraform destroy.

---

## 🧪 Deploying with the Makefile (replaces earlier manual deploy guidance)

This repository uses the Makefile workflow for the recommended deploy steps. The Makefile drives Terraform init/plan/apply and other convenience tasks so you do not need to run ad-hoc kubectl/helm commands as part of the standard infra deploy.

Typical flow (from a fresh machine)
1. Clone:
```bash
git clone https://github.com/its-d/terraform-aws-eks-microservice-framework.git
cd terraform-aws-eks-microservice-framework
```
2. Configure Virtual Environment
```bash
# Create Virtual Environment
python3 -m venv .venv

# Enter/Use the Virtual Environment
source .venv/bin/activate

# Install packages
pip install -r requirements.txt
```

3. Set your AWS_PROFILE/Credentials
```bash
export AWS_PROFILE=<PROFILE_NAME>
```

5. Create env folder
```bash
mkdir -p env/dev
```

6. Create `backend.hcl` locally (example above), do NOT commit it.
```bash
cp backend.hcl.example env/dev/backend.hcl
# Edit env/dev/backend.hcl - populate required fields (see section above)
```

7. Create environment tfvars:
```bash
cp terraform.tfvars.example env/dev/terraform.tfvars
# Edit env/dev/terraform.tfvars - populate required fields (see section above)
```

8. Confirm your IP (REQUIRED)
```bash
make _confirm_ip
```

9. Initialize Terraform:
```bash
make init
```

10. Plan:
```bash
make plan
```

11. Apply:
```bash
make apply
```

After apply
- Use `make outputs` (if available in the Makefile) to retrieve important values such as the cluster name, EFS ID's (Grafana Endpoint is located within Load Balancer Service in the AWS Console).
- If your team manages application manifests (Helm, GitOps), apply them through your standard CI/GitOps pipeline rather than including them in the infra Makefile.

This Makefile-driven flow avoids embedding ad-hoc kubectl commands in the README or in CI for provisioning infrastructure.

---

## 🔁 CI and pre-commit

- Install pre-commit and run locally:
```bash
pre-commit install
pre-commit run --all-files
```
- CI runs the same hook set, installs pinned CLI tools (terraform-docs, kubeconform, addlicense) and caches pre-commit for speed.
- CI initializes Terraform with `-backend=false` so it does not need S3/DynamoDB credentials; it validates formatting and generates a plan artifact for PRs.

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
[LinkedIn](https://www.linkedin.com/in/darian-873)
