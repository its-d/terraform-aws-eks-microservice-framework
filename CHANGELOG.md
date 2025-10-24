# Changelog

## [0.1.0] - 2025-10-24
### 🚀 Initial Release
- Added Terraform modules for:
  - EKS (Fargate-only)
  - VPC, IAM, and Security groups
  - EFS storage with Grafana persistence
  - AWS Load Balancer Controller
- Integrated Helm deployments and K8s provider configuration
- Added automated cleanup via Makefile (ENIs, ALBs, namespaces)
- Included example env config (`env/dev/terraform.tfvars`)
- Added pre-commit hooks, linting, and docs automation
- Fix hanging deletes by pre-cleaning ENIs before VPC destroy
- Remove Kubernetes finalizers automatically during teardown

### ✨ Feature Additions
- Added `_aws_net_purge` and `_force_k8s_purge` targets in Makefile
- Expanded documentation (README + /docs)
