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
- `modules/*` — VPC, EKS, IAM, Grafana, app, etc.
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
bucket         = "my-terraform-state-bucket"
key            = "terraform-aws-eks-microservice-framework/ENV/terraform.tfstate" # use per-environment path
region         = "us-east-1"
encrypt        = true
dynamodb_table = "my-terraform-state-locks"  # optional but recommended
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

7. Configure kubectl:
```bash
aws eks update-kubeconfig --name <cluster_name_from_outputs> --region <region>
# Use terraform output to find cluster name if needed
terraform output -json | jq .
```

8. Deploy sample app:
```bash
kubectl apply -f k8s/deployment-hello-world.yaml
kubectl apply -f k8s/service-hello-world.yaml
kubectl get svc -w hello-world
```

9. Grafana access:
- After apply, get Grafana service/endpoint via `kubectl get svc -n monitoring` or from Terraform outputs. Grafana is backed by the EFS created by Terraform (when enabled), so dashboards persist across pod restarts.

---

## 🔁 CI and pre-commit

- Install pre-commit and run locally:
```bash
pre-commit install
pre-commit run --all-files
```
- CI should run `terraform fmt`, `terraform validate`, and pre-commit checks.

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
