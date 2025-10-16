# Terraform AWS EKS Microservice Framework

**Author:** Darian Lee
**License:** Apache-2.0

---

## Overview

The **Terraform AWS EKS Microservice Framework** is a reusable, opinionated baseline for spinning up an **EKS cluster** and its core AWS scaffolding using Terraform. It’s intended as a “plug-and-play” starting point that you (or others) can clone, set environment values, and deploy.

- Fast bootstrap of an EKS-ready AWS environment
- Consistent Infrastructure-as-Code patterns
- Pre-commit quality gates for Terraform, YAML/JSON, and Python helper scripts
- Makefile for smooth developer ergonomics

---

## Prerequisites

### System tools (install via Homebrew)

Create a `Brewfile` with the following and run `brew bundle install`:

```bash
brew "terraform"
brew "tflint"
brew "terraform-docs"
brew "addlicense"
brew "python@3.11"
brew "pre-commit"
brew "make"
brew "git"
```

Then:

```bash
brew bundle install
```

### Python (for pre-commit)

Create a virtual environment and install:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install pre-commit==4.3.0 PyYAML==6.0.3
```

*(If you keep a `requirements.txt`, include at least: `pre-commit==4.3.0` and `PyYAML==6.0.3`.)*

---

## Quick Start

```bash
git clone https://github.com/<your-username>/terraform-aws-eks-microservice-framework.git
cd terraform-aws-eks-microservice-framework

# One-time: install pre-commit hooks
pre-commit install

# Pick an environment (dev/test/prod). ENV is required by Makefile targets.
export ENV=dev

# Initialize, plan, and apply
make init
make plan
make apply
```

To tear down:

```bash
export ENV=dev
make destroy
```

---

## Repository Structure

```
terraform-aws-eks-microservice-framework/
├── .github/
│   └── workflows/
│       └── ci.yml
│
├── .terraform/                  # Local Terraform metadata (auto-created)
├── .venv/                       # Python virtual environment
│
├── docs/                        # Documentation folder (architecture, usage)
│
├── envs/                        # Environment-specific deployments
│   ├── dev/
│   │   └── terraform.tfvars
│   ├── test/
│   └── prod/
│
├── k8s/                         # Kubernetes manifests or configs
│   └── .gitkeep
│
├── modules/                     # Reusable Terraform modules
│   ├── app/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── provider.tf
│   │   └── variables.tf
│   ├── eks/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── provider.tf
│   │   └── variables.tf
│   ├── iam/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── provider.tf
│   │   └── variables.tf
│   ├── security/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── provider.tf
│   │   └── variables.tf
│   └── vpc/
│       ├── main.tf
│       ├── outputs.tf
│       ├── provider.tf
│       └── variables.tf
│
├── scripts/                     # Automation scripts
│   ├── init.sh
│   ├── plan.sh
│   ├── apply.sh
│   └── destroy.sh
│
├── .gitignore
├── .license-header.txt
├── .pre-commit-config.yaml
├── backend.tf
├── CHANGELOG.md
├── LICENSE
├── main.tf
├── Makefile
├── NOTICE
├── README.md
├── requirements.txt
├── variables.tf
└── VERSION
```

**Environments** live under `envs/<name>` and hold:
- `main.tf` — root calls to modules (vpc/eks/iam/security)
- `variables.tf` — inputs for that environment
- `terraform.tfvars` — environment-specific variable values

---

## Makefile Commands

| Command | Description |
|----------|-------------|
| `make init` | Initialize Terraform for the current environment |
| `make plan` | Generate an execution plan |
| `make apply` | Apply the Terraform plan |
| `make destroy` | Destroy Terraform-managed resources |
| `make validate` | Validate configuration files |
| `make fmt` | Format Terraform code recursively |
| `make lint` | Run all pre-commit hooks |
| `make docs` | Generate Terraform module documentation |
| `make clean` | Clean up local state files |
| `make help` | Display all available commands |

> 💡 If no environment variable is set (`ENV`), `make` will prompt you interactively.

---

## Quality Gates (Pre-Commit)

This framework uses pre-commit hooks to enforce code quality before every commit.

### Checks Included
- ✅ Terraform format, validate, lint, and docs
- ✅ Python code style (Black, Flake8)
- ✅ YAML and JSON linting
- ✅ Apache 2.0 license headers
- ✅ Merge conflict and whitespace checks

Run manually:

```bash
pre-commit run --all-files
```

---

## License

```
Copyright 2025 Darian Lee

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
