# Contributing Guide

---

## Contribution Workflow

1. Fork and create a feature branch:
```bash
git checkout -b feature/my-change
```

2. Run formatting and tests:
```bash
make fmt
make lint
make validate
```

3. Plan with example tfvars:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars (region, identifier)
make plan
```

4. Push and open a PR with description and verification steps.

---

## Local Development

- **Format:** `make fmt`
- **Validate:** `make validate`
- **Lint:** `make lint`
- **Docs:** `make docs`
- **Tests:** `make test`

---

## Module Guidelines

- Each module: `main.tf`, `variables.tf`, `outputs.tf`, `README.md`
- Use variables for environment-specific values.
- Avoid hard-coded ARNs or regions.

---

## Secrets

- Never commit `terraform.tfvars` or `backend.hcl`.
- Grafana credentials: created via `make plan` prompt or manually in Secrets Manager.
- Terraform state contains sensitive values; use S3 backend with encryption.
