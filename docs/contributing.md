# 🤝 Contributing Guide

Thank you for contributing!

---

## Contribution Workflow

1. Fork the repository and create a feature branch:
```bash
git checkout -b feature/my-change
```

2. Implement changes; run formatting and tests locally:
```bash
make fmt
pre-commit run --all-files
terraform validate
```

3. Run a plan for an isolated environment:
```bash
cp terraform.tfvars.example env/dev/terraform.tfvars
# edit env/dev/terraform.tfvars
make plan ENV=dev
```

4. Push your branch and open a PR describing the change, motivation, and verification steps.

---

## Local Development & Testing

- Formatting:
```bash
make fmt
```

- Validation:
```bash
make validate
tflint  # if installed
```

- Generating docs for modules:
```bash
make docs
```

- Pre-commit:
```bash
pre-commit install
pre-commit run --all-files
```

---

## Module Guidelines

- Each module should be self-contained:
  - main.tf
  - variables.tf
  - outputs.tf
  - README.md (module level)
  - examples/ (optional but recommended)
- Keep modules small and focused.
- Use variables for all environment-specific values — avoid hard-coded ARNs or regions.

---

## PR Requirements

- All changes must pass pre-commit checks.
- Add/Update module README when adding or significantly changing a module.
- Document breaking changes in CHANGELOG.md.
- Tag reviewers and add a clear description of the impact.

---

## Secrets & Sensitive Values

- Never commit secrets or credentials.
- Use env/<env>/terraform.tfvars only locally; add env/* to .gitignore if necessary.
- Use SSM Parameter Store / Secrets Manager for production secrets if desired.

---
