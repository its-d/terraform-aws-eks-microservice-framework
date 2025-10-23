# 🚀 terraform-aws-eks-microservice-framework

A modular, production-ready Terraform framework for deploying Amazon EKS and running microservices (Fargate-backed). This repository provisions networking, IAM/IRSA, EKS control plane, the AWS Load Balancer Controller, and example app manifests so teams can stand up a repeatable EKS environment.

---

## 🎯 Project / Goal / Who this is for

- Goal: Provide a repeatable, auditable baseline to provision an EKS cluster (Fargate profiles), application scaffolding, monitoring (Grafana), and ALB/NLB integration using Terraform modules.
- Who it's for: Infrastructure engineers and platform teams who want an opinionated Terraform starting point for microservice deployments on AWS EKS with least-privilege IAM and modular architecture.
- Typical uses: PoC, staging, and production clusters where you want Terraform-driven infra + Kubernetes manifests managed by developers/operators.

---

## ⚙️ Prerequisites (clean machine)

Below are the tooling packages someone needs to install from a clean OS. Commands are examples — adapt for your OS/version.

Minimum recommended pinned versions (tested): Terraform >= 1.6, AWS CLI v2, Helm >= 3.8, kubectl compatible with the EKS control plane version, Python >= 3.10.

- System tools
  - git
  - make
  - unzip
  - curl
  - jq (JSON CLI helper)
  - yq (YAML CLI helper, optional)
- Docker (for building images, optional): Docker Desktop (macOS/Windows) or docker-ce (Linux)
- Terraform CLI (>= 1.6)
- AWS CLI v2
- kubectl (matches EKS control plane: use aws eks update-kubeconfig after cluster creation)
- eksctl (optional; not required if you only use Terraform, but useful for quick EKS workflows)
- Helm (>= 3.8)
- Python 3.10+ and pip (for pre-commit hooks)
- pre-commit (pip install pre-commit)
- terraform-docs (used by Make docs target)
- tflint (optional; recommended)
- kubeconform (optional; used in pre-commit for Kubernetes manifest validation)
- Node.js + npm (optional — repo does not require node by default; include only if you add frontend tooling)
- Windows users: consider using WSL2 (Ubuntu) for consistent behavior with the Makefile.

Installation examples:

macOS (Homebrew)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew update
brew install git make terraform awscli kubectl helm jq yq python3 pre-commit terraform-docs tflint
# Docker Desktop from https://www.docker.com/products/docker-desktop
```

Ubuntu (apt)
```bash
sudo apt update && sudo apt install -y git make unzip curl jq
# Install Terraform (recommended: HashiCorp apt repository)
# Install AWS CLI v2 (bundled installer)
# Install kubectl via apt or from k8s.io
# Install helm via script or apt
python3 -m pip install --user pre-commit terraform-docs
```

Windows
- Use WSL2 (Ubuntu) or use native installers for Terraform, AWS CLI, Docker Desktop, kubectl, Helm.
- Alternatively: winget / choco for installers.

---

## 🔐 AWS account and credentials

- Configure AWS credentials for the profile you'll use:
  - aws configure --profile <profile>
  - Or set AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN and AWS_DEFAULT_REGION.
- The account should have permissions to create IAM roles, S3/DynamoDB (for remote state), EKS clusters, VPC resources, and ELB/ALB target groups.

---

## 🗂 Repository structure (relevant parts)

- main.tf — root orchestration of modules
- variables.tf — global inputs
- output.tf — exported outputs
- backend.tf — backend configuration placeholder (see below)
- alb_controller.tf — AWS Load Balancer Controller (Helm)
- Makefile — common workflow targets (init, plan, apply, destroy, etc.)
- modules/* — VPC, EKS, IAM, Grafana, app, etc.
- env/<env>/terraform.tfvars — environment-specific variables (create these)
- k8s/* — sample Kubernetes manifests
- docs/* — architecture, contributing, troubleshooting

---

## 🔧 Backend (backend.hcl) — example & explanation

This repo expects a remote state backend in S3 with optional DynamoDB state locking. Create a backend.hcl (local file, not committed) and supply it when running terraform init (or configure in CI).

Example backend.hcl:
```hcl
bucket         = "my-terraform-state-bucket"
key            = "terraform-aws-eks-microservice-framework/terraform.tfstate" # path to state file
region         = "us-east-1"
encrypt        = true
dynamodb_table = "my-terraform-state-locks" # optional but recommended for locks
acl            = "private"
role_arn       = "arn:aws:iam::123456789012:role/CI-Terraform-Role" # optional (use if assuming a role)
```

Fields to populate:
- bucket — an existing S3 bucket you or your organization controls
- key — path within bucket to store the state file (per environment is recommended)
- region — bucket region
- encrypt — true recommended
- dynamodb_table — create a DynamoDB table with Partition Key "LockID" if you want state locking
- role_arn — optional IAM role to assume for Terraform runs

How to use:
- keep backend.hcl locally (do not commit).
- terraform init -backend-config=backend.hcl

---

## 🧾 Environment tfvars — path and required fields

Makefile uses: env/$(ENV)/terraform.tfvars as the env TFVARS file. Example file is terraform.tfvars.example. You must copy that example into env/dev/terraform.tfvars (or env/prod/...) and populate values.

Minimum fields from terraform.tfvars.example and modules:
- region = "us-east-1"
- environment = "dev"
- owner = "YOUR_NAME"
- identifier = "project-prefix"
- endpoint_private_access = true / false
- endpoint_public_access = true / false
- public_access_cidrs = ["x.x.x.x/32"] (if public access)
- grafana_admin_user = "admin" (if using Grafana)
- grafana_admin_password = "secure-password"

Other module variables (may be required depending on your module inputs):
- private_subnet_ids = ["subnet-...","subnet-..."] (if you supply your own subnets)
- cluster_role_arn = "arn:aws:iam::...:role/eks-cluster-role" (if you pre-create a role)
- pod_execution_role_arn = "arn:aws:iam::...:role/eks-pod-exec" (IRSA/pod execution role)

Important:
- Do not commit real credentials. Add env/* to .gitignore if you haven't already.
- Use a unique identifier for resource naming to avoid collisions across environments.

---

## 🧭 Makefile: targets and explanations

Makefile (root) provides convenience wrappers around Terraform and repo tooling. Exact targets present:

- init
  - Purpose: Run terraform init -upgrade in root and then in each module directory.
  - Use: first step after cloning and creating backend.hcl & env tfvars.
  - Example: make init ENV=dev
  - Notes: Runs init on each module to ensure plugin/downloads and module-level backend configs are set up.

- plan
  - Purpose: terraform plan using env tfvars; writes plan to plan-<env>.tfplan
  - Guard: fails if env/$(ENV)/terraform.tfvars is missing.
  - Example: make plan ENV=dev

- apply
  - Purpose: terraform apply using the generated plan file plan-<env>.tfplan
  - Example: make apply ENV=dev

- destroy
  - Purpose: terraform destroy -var-file=$(TFVARS)
  - Example: make destroy ENV=dev
  - IMPORTANT ordering note (see below on ENIs / Kubernetes resources)

- validate
  - Purpose: terraform validate (root)

- fmt
  - Purpose: terraform fmt -recursive

- lint
  - Purpose: runs pre-commit checks across repository (formatting, linting, kubeconform, etc.)

- docs
  - Purpose: generate Terraform docs for each module using terraform-docs

- clean
  - Purpose: remove local artifacts: .terraform, .terraform.lock.hcl, plan files

- help
  - Purpose: prints available Make targets and usage.

---

## ⚠️ Why delete Kubernetes resources (and ENIs) before terraform destroy?

Common failure: terraform destroy fails because AWS reports resources are in use (ENIs attached, load balancers/target groups referenced).

Why:
- Kubernetes (and Kubernetes controllers such as the AWS Load Balancer Controller) create AWS resources (ENIs, target groups, security group rules) dynamically. If Terraform tries to destroy underlying networking resources (subnets, VPC, security groups) while those dynamically created resources still exist and are attached, AWS blocks the deletion with "resource in use" errors.
- Fargate pods attach ENIs to provide pod networking. Those ENIs must be removed before deleting subnets or VPCs.

Recommended ordering:
1. Delete application Kubernetes resources (Services, Ingresses, Deployments) so controllers detach and remove cloud resources:
   - kubectl delete -f k8s/service-hello-world.yaml
   - kubectl delete -f k8s/deployment-hello-world.yaml
   - kubectl -n kube-system delete deploy aws-load-balancer-controller (if you installed it manually)
2. Wait until all pods and ENIs are gone. Verify:
   - kubectl get pods -A
   - Check EC2 console -> Network Interfaces: look for ENIs associated with your cluster and ensure none remain in-use.
3. Run make destroy ENV=dev
4. If terraform still errors, find blocking resources with terraform state list or AWS console and remove them manually:
   - terraform state rm <resource_address>   # removes from state (use with caution)
   - then terraform destroy -auto-approve

This repository’s Makefile does not automatically delete Kubernetes resources because that action requires kubeconfig + proper permissions and is destructive. You should manually remove K8s resources before calling make destroy to avoid stuck resource-in-use errors.

---

## 🧪 Full deploy (from fresh machine)

1. Clone:
```bash
git clone https://github.com/its-d/terraform-aws-eks-microservice-framework.git
cd terraform-aws-eks-microservice-framework
```

2. Prepare backend.hcl (local, never commit). Example shown above.

3. Create environment tfvars:
```bash
mkdir -p env/dev
cp terraform.tfvars.example env/dev/terraform.tfvars
# Edit env/dev/terraform.tfvars and populate required fields
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
# cluster_name is output from Terraform (check `terraform output` or output.tf)
```

8. Deploy sample app:
```bash
kubectl apply -f k8s/deployment-hello-world.yaml
kubectl apply -f k8s/service-hello-world.yaml
kubectl get svc -w hello-world
```

---

## 🔁 CI and pre-commit

- Run pre-commit checks locally before pushing:
```bash
pre-commit run --all-files
```
- Makefile lint target also runs pre-commit.

---

## 📚 Documentation

See the docs/ directory for architecture, contributing, and troubleshooting guides (updated versions are included in this commit).

---

## ⚖️ License

Apache License 2.0 — see LICENSE.

---

## 👤 Author

**Darian Lee** — Infrastructure Engineer & Cloud Consultant
