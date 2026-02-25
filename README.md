# terraform-aws-eks-microservice-framework

A modular Terraform framework for deploying Amazon EKS with Fargate. Provisions VPC, IAM/IRSA, EKS control plane, AWS Load Balancer Controller, and Grafana. Designed for cloud-knowledgeable users new to EKS.

---

## Quick Start

```bash
# 1. Copy config files
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl

# 2. Edit terraform.tfvars: set region, identifier
# 3. Edit backend.hcl: set bucket, key, region

# 4. Deploy
make init
make plan   # Prompts for Grafana credentials if not set
make apply
```

**Grafana:** After apply, get the URL from AWS Console → EC2 → Load Balancers (ALB for `monitoring` namespace). Use `make grafana-url` for cluster info.

---

## Prerequisites

- Terraform >= 1.5
- AWS CLI v2
- kubectl, Helm >= 3.8
- jq
- Python 3.10+ (for pre-commit)

---

## Configuration

### Root-level files

| File | Purpose |
|------|---------|
| `terraform.tfvars` | Your variables (copy from `terraform.tfvars.example`) |
| `backend.hcl` | S3 backend config (copy from `backend.hcl.example`) |

### Required variables

- **region** — AWS region (default: `us-east-1`)
- **identifier** — Short prefix for resource names (e.g., `myapp`)

### Grafana credentials

On first `make plan`, if `grafana_admin_user_arn` and `grafana_admin_pwd_arn` are empty, you'll be prompted for username and password. The script creates Secrets Manager secrets and updates `terraform.tfvars`.

### Optional

- **public_access_cidrs** — CIDRs for EKS API access (default: `["0.0.0.0/0"]`). Use `make confirm-ip` to restrict by IP.
- **enable_https** / **certificate_arn** — Enable HTTPS for Grafana with an ACM certificate.

---

## Makefile Targets

| Target | Description |
|--------|-------------|
| `init` | Initialize Terraform (requires `backend.hcl`) |
| `plan` | Plan (prompts for Grafana creds if needed) |
| `apply` | Apply plan |
| `destroy` | Pre-cleanup + destroy |
| `outputs` | Show Terraform outputs |
| `grafana-url` | Show Grafana access info |
| `validate` | Validate config |
| `fmt` | Format Terraform files |
| `lint` | Run pre-commit |
| `test` | Run Terraform module tests |
| `confirm-ip` | Helper to set `public_access_cidrs` |

---

## Destroy

`make destroy` runs a pre-cleanup script (Helm uninstall, K8s resources, ALBs, ENIs) before `terraform destroy`. No manual steps required.

---

## Repository Structure

```
.
├── main.tf              # Root orchestration
├── variables.tf
├── outputs.tf
├── alb_controller.tf    # AWS Load Balancer Controller Helm
├── terraform.tfvars.example
├── backend.hcl.example
├── Makefile
├── modules/
│   ├── vpc/             # VPC, subnets (region-derived AZs)
│   ├── eks/             # EKS cluster, Fargate, CoreDNS
│   ├── iam/             # Cluster + pod execution roles
│   ├── iam_irsa/        # IRSA for Load Balancer Controller
│   └── grafana/         # Grafana Helm + ingress
└── scripts/
    ├── pre-destroy-cleanup.sh
    └── setup-grafana-secrets.sh
```

---

## EKS Control Plane Logging

Control plane logs (API, audit, authenticator) are sent to CloudWatch. Use Grafana with a CloudWatch Logs datasource to view them.

---

## Documentation

- [docs/architecture.md](docs/architecture.md) — Architecture overview
- [docs/contributing.md](docs/contributing.md) — Contribution workflow
- [docs/troubleshooting.md](docs/troubleshooting.md) — Common issues
- [docs/REFACTOR_SPEC.md](docs/REFACTOR_SPEC.md) — Refactor specification

---

## License

Apache License 2.0 — see [LICENSE](LICENSE).
