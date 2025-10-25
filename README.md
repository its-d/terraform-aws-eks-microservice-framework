# 🚀 terraform-aws-eks-microservice-framework

A modular, production-ready Terraform framework for deploying Amazon EKS and running microservices (Fargate-backed). This repository provisions networking, IAM/IRSA, the EKS control plane, the AWS Load Balancer Controller, and a ready-to-use Grafana deployment with persistent storage managed by Amazon EFS so teams can stand up a repeatable EKS environment with durable monitoring storage.

---

## 🎯 Project / Goal / Who this is for

- Goal: Provide a repeatable, auditable baseline to provision an full EKS platform (Fargate profiles), CI-friendly Terraform modules, monitoring (Grafana with persistent EFS storage), and load balancing integration (ALB/NLB) using opinionated, modular Terraform.
- Who it's for: Infrastructure engineers, platform teams, and DevOps who need a production-oriented starting point for microservice deployments on AWS EKS with least-privilege IAM and clear operational procedures.
- Typical uses: PoC, staging, and production clusters where Terraform manages infrastructure and provides an out-of-the-box Grafana that persists dashboards and plugins across redeploys.

---

## Quick first-time checklist (do these before running apply)
1. Create remote state artifacts (S3 bucket + DynamoDB table) or have a backend.hcl ready:
   - S3 bucket (private) for Terraform state
   - DynamoDB table with partition key "LockID" for state locking (recommended)
2. Copy example tfvars and populate required fields:
   - `cp terraform.tfvars.example env/dev/terraform.tfvars`
   - Edit `env/dev/terraform.tfvars` (see "env tfvars" below)
3. Ensure you have the minimum toolchain installed (Terraform, AWS CLI, kubectl, Helm, Python + pre-commit).
4. Run: `make init ENV=dev` (or `terraform init -backend-config=backend.hcl`) and ensure init succeeds.
5. Run: `make plan ENV=dev` then `make apply ENV=dev`.

Tip: Use a feature branch and open a PR so CI validates formatting and terraform validation before merging to main.

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
- Required permissions (high-level):
  - Create IAM roles/policies, EKS clusters, VPC resources, EC2 ENIs, ELB/ALB resources, EFS resources (if Terraform will create them), S3/DynamoDB for state.

Security note: Do not put secrets in git. See "Secrets & Sensitive Values" below for recommended patterns.

---

## 🗂 Repository structure (relevant parts)

- `main.tf` — root orchestration of modules
- `variables.tf` — global inputs
- `output.tf` — exported outputs
- `backend.tf` — remote state backend config placeholder
- `alb_controller.tf` — AWS Load Balancer Controller Helm configuration
- `Makefile` — convenience workflow targets (init, plan, apply, destroy, etc.)
- `modules/*` — VPC, EKS, IAM, storage, Grafana, app, etc.
- `env/<env>/terraform.tfvars` — environment-specific variables (create these)
- `k8s/*` — sample Kubernetes manifests
- `docs/*` — architecture, contributing, troubleshooting
- `.github/workflows/ci.yml` — CI pipeline (pre-commit, terraform validate, plan artifacts)

---

## 📌 Grafana (ready-to-use) with EFS — primary feature

This repository includes a Grafana deployment wired to persistent storage managed by the storage module (EFS) and exposed to Grafana via PersistentVolume/PersistentVolumeClaim.

Important behavioral note (default flow)
- The `modules/storage` module creates the EFS file system, mount targets, and access point when deployed. The root `main.tf` instantiates `module.storage` and passes its outputs to `module.grafana`.
- Do NOT set `efs_file_system_id` or `efs_access_point_id` in `env/<env>/terraform.tfvars` for the default workflow — these IDs are produced by Terraform and exposed as module outputs.
- If you intentionally want to reuse an external EFS created outside this repo, that is an advanced workflow: you must update module usage or supply optional variables to accept external IDs. (The current default wiring uses `module.storage` to create EFS.)

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
- After apply, retrieve the Grafana service/endpoint:
  - `kubectl get svc -n monitoring` (service type depends on helm values; often ClusterIP with an ingress or LoadBalancer via AWS Load Balancer Controller)
  - Or inspect Terraform outputs (if the grafana module exposes an output for the URL)

---

## 🔧 First-time backend / bootstrap (recommended)

You can create the backend resources manually or with a small helper. Example Terraform snippet to create a state S3 bucket & DynamoDB table (run in a separate one-off bootstrap workspace) is provided in `scripts/bootstrap-backend.example.tf` (suggestion). If you prefer commands, create the S3 bucket and DynamoDB table via AWS console / CLI.

Example backend.hcl (local file; do NOT commit):
```hcl
bucket         = "my-terraform-state-bucket"
key            = "terraform-aws-eks-microservice-framework/ENV/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "my-terraform-state-locks"
acl            = "private"
role_arn       = "arn:aws:iam::123456789012:role/CI-Terraform-Role" # optional
```

Usage:
```bash
terraform init -backend-config=backend.hcl
# or
make init ENV=dev
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
- Do NOT set `efs_file_system_id` or `efs_access_point_id` in `env` tfvars for the default behavior. The storage module creates EFS and the root module wires its outputs into grafana. If you intend to reuse an externally-managed EFS, you must explicitly configure that advanced flow.

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

Recommended additions (suggested changes you can add to the Makefile)
- `make outputs` — convenience target to show key outputs:
```makefile
outputs:
	@echo "Cluster name: $$(terraform output -raw cluster_name 2>/dev/null || echo '<not set>')"
	@echo "Grafana EFS FS ID: $$(terraform output -raw efs_file_system_id 2>/dev/null || echo '<not set>')"
	@echo "Grafana EFS AP ID: $$(terraform output -raw efs_access_point_id 2>/dev/null || echo '<not set>')"
```

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

7. Configure kubectl:
```bash
aws eks update-kubeconfig --name <cluster_name_from_outputs> --region <region>
# Use terraform output to find cluster name:
terraform output cluster_name
```

8. Deploy sample app:
```bash
kubectl apply -f k8s/deployment-hello-world.yaml
kubectl apply -f k8s/service-hello-world.yaml
kubectl get svc -w hello-world
```

9. Grafana access:
- After apply, get Grafana service/endpoint via `kubectl get svc -n monitoring` or from Terraform outputs if the grafana module exposes them (recommended).
- Grafana is backed by the EFS created by the storage module (when enabled), so dashboards persist across pod restarts.

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
