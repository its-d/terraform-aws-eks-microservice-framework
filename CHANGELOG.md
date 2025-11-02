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
### 🎯 Secrets Manager Credential Handler
- Added Secrets Manager Import for Grafana Credentials.
  - Values are plugged into Secrets Manager via AWS Console, and Secrets are imported into the Grafana Module

----

## [v0.3.0] - 2025-11-02
### 🎯 HTTPS w/ Certificate Enablement
- Added HTTPS functionality to Grafana
  - `enable_https` is configured in the .tfvars (within env/<directory>) and uses the certificate_arn in .tfvars to configure HTTPS connections

----

## [v1.0.0] - 2025-11-02
### 🚀 Production Baseline Release
- Marked as the first **stable, feature-complete** release of the Terraform AWS EKS Microservice Framework.
- Framework now supports:
  - Full **EKS Fargate-only** environment (no EC2 workers)
  - **ALB ingress** via AWS Load Balancer Controller
  - **Grafana deployment** with Helm and namespace isolation
  - **HTTPS toggle** using `enable_https` in `.tfvars`
  - Support for both **IAM server certificates** and **ACM certificates**
- Security and networking:
  - Dynamic **Security Group rules** tied to `enable_https`
  - IP confirmation guardrail for safe public access
  - Clean teardown with automatic ALB, ENI, and tag cleanup
- Automation & Dev Experience:
  - Streamlined **Makefile commands** for init, plan, apply, destroy, and forced cleanup
  - Modular structure with reusable patterns for future add-ons
  - Supports **custom environments** (`env/dev`, `env/stage`, etc.)

### 🧭 Next Milestone (v1.1.0 - In Progress)
- Add **EFS persistent storage** integration for Grafana
  - Optional flag-based persistence (`enable_persistence`)
  - Provisioned via EFS CSI driver and StorageClass
- Add automated **dashboard retention** and **SSL redirect logic**
- Improved test coverage for multi-environment pipelines
