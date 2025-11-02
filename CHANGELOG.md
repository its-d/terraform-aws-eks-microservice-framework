# Changelog

## [v0.1.0] - 2025-10-24
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

----

## [v0.2.0] - 2025-10-30
### 🎯 Initial Stable Release
- Added Secrets Manager Import for Grafana Credentials.
  - Values are plugged into Secrets Manager via AWS Console, and Secrets are imported into the Grafana Module

----

## [v0.3.0] - 2025-11-02
### 🎯 Initial Stable Release
- Added HTTPS functionality to Grafana
  - `enable_https` is configured in the .tfvars (within env/<directory>) and uses the certificate_arn in .tfvars to configure HTTPS connections
