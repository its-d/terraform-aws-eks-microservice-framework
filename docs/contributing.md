# 🤝 Contributing Guide

Thank you for your interest in contributing to **terraform-aws-eks-microservice-framework**!

---

## 🧩 Contribution Workflow

1. **Fork** the repository and create a feature branch:
   ```bash
   git checkout -b feature/my-improvement
   ```

2. **Run all pre-commit checks** before pushing:
   ```bash
   pre-commit run --all-files
   ```

3. **Test your Terraform changes**:
   ```bash
   make plan ENV=dev
   ```

4. **Submit a Pull Request (PR)** describing your change and its purpose.

---

## 🧰 Local Setup

### Prerequisites
- Terraform >= 1.6
- AWS CLI (authenticated with appropriate permissions)
- Python >= 3.10
- pre-commit (`pip install pre-commit`)

### Recommended Extensions
- **VSCode Terraform Extension**
- **YAML / JSON Linter**
- **Prettier** for consistent formatting

---

## 🧪 Testing

You can spin up isolated test environments using environment-specific `.tfvars` files under `/env`.

Example:
```bash
make apply ENV=dev
```

Run unit-like checks via Terraform’s built-in validation:
```bash
terraform validate
tflint
```

---

## 🔍 Code Style

- Follow **Terraform naming conventions** for variables and outputs.
- Use **snake_case** for variables, **kebab-case** for resources.
- Every file must contain the **Apache-2.0 license header**.
- Keep modules **small and reusable**.

---

## 📦 Submitting Modules

Each module should:
- Be self-contained (`main.tf`, `variables.tf`, `outputs.tf`).
- Contain a `README.md` explaining usage.
- Have `examples/` if complex.

---

## 🚀 Deployment Verification

Ensure new or updated resources deploy cleanly via:
```bash
make apply ENV=dev
kubectl get pods -A
kubectl get svc -A
```

Once verified, commit and push your changes!

---
