# Terraform Template Framework (Internal)

This repository serves as the internal foundation for building and testing standardized Terraform project structures.
It’s used to define conventions, enforce structure, and simplify the setup of reusable Infrastructure-as-Code (IaC) templates.

---

## 📘 Purpose

The goal of this repo is to create a **reusable, consistent Terraform project framework** that can be quickly adapted for:
- AWS baseline environments (e.g., networking, IAM, S3, CloudWatch)
- Client or internal proof-of-concepts
- Ventrov-ready infrastructure templates

This is not a public starter kit — it’s the **internal sandbox** where structure, patterns, and automation are tested before being rolled out.

---

## 🧱 Repository Structure

```plaintext
terraform-template-framework/
├── .github/                  # CI/CD workflows (linting, format, security scans)
├── modules/                  # Reusable Terraform modules
├── envs/                     # Environment configurations (dev, staging, prod)
├── scripts/                  # Helper scripts for init/plan/apply
├── policy/                   # Sentinel/OPA policies (optional compliance)
├── docs/                     # Internal notes, architecture diagrams, or references
├── Makefile                  # Common commands (e.g., fmt, validate, plan)
├── README.md                 # You are here
├── .pre-commit-config.yaml   # Linting + security hooks
└── .gitignore                # Ignored files and sensitive data exclusions

---

## ⚙️ Current Development Focus

1. Finalize baseline Terraform structure (modules, envs, backend)
2. Implement reusable script flow (`tf-init.sh`, `tf-plan.sh`, etc.)
3. Add linting and validation workflows under `.github/workflows`
4. Define tagging and naming standards for resources
5. Prepare base documentation for conversion into public Starter Kit

---

## 🧩 Notes

- `examples/` intentionally omitted for now — focus is on building core framework logic.
- Will later fork to **Ventrov public repos** (`ventrov/aws-starter-kit`, etc.).
- `scripts/` may include helper logic for backend setup, environment variable loading, or automated validation (currently placeholder).
- `policy/` directory reserved for future integration of compliance-as-code (Checkov, OPA, or Sentinel).

---

## 🔒 Usage

This repo is **internal-use only**.
It can be cloned, copied, or referenced for new project scaffolds but **should not be made public** until formalized into a reusable product.

---

## 🧭 Next Steps

- [ ] Build minimal functional AWS baseline deployment (VPC, S3, IAM)
- [ ] Add Makefile commands for consistency
- [ ] Add GitHub Actions workflow for validation
- [ ] Document reusable patterns and testing conventions
- [ ] Prep conversion into `ventrov/aws-starter-kit` (public)

---

**Author:** Darian Lee
**Status:** Internal Development
**Visibility:** Private Repository
