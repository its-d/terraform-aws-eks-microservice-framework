# Changelog

## [1.0.0] - 2025-10-24
### 🎯 Initial Stable Release
- Finalized Terraform AWS EKS Microservice Framework
- Supports:
  - AWS VPC, IAM, Security, and EKS (Fargate)
  - Grafana with ephemeral Storage
  - AWS Load Balancer Controller with ALB ingress
- Includes:
  - Complete `Makefile` automation for deploy/destroy and cleanup (ALBs, ENIs, K8s)
  - Environment variable examples (`env/dev/backend.hcl`, `terraform.tfvars`)
  - Full documentation under `/docs` for setup, architecture, troubleshooting, and contributing
- Verified clean apply/destroy cycles
- Ready for multi-environment use
