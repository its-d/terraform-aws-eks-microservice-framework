# 🚀 terraform-aws-eks-microservice-framework

A modular, production-ready Terraform framework for deploying **AWS EKS (Elastic Kubernetes Service)** and running **microservices on AWS Fargate**.
This project provisions a fully functional EKS cluster, configures networking, IAM roles, and security, and deploys a sample “hello-world” application through Kubernetes manifests to verify the setup.

---

## 🧠 Overview

This repository is designed to help you:
- Stand up a complete **EKS on Fargate** environment using Terraform.
- Automate IAM, networking, and Kubernetes add-on configuration.
- Enforce consistent quality through pre-commit checks and CI/CD.
- Provide a reusable structure for deploying future microservices.

It’s modular, opinionated, and built for teams that want repeatable, auditable, and secure infrastructure.

---

## 🏗️ Architecture

**Core Flow**
1. **VPC Module** — builds the private and public subnets, route tables, and NAT gateways.
2. **EKS Module** — deploys the EKS control plane with Fargate-only compute profiles.
3. **IAM / IRSA Modules** — creates service-linked IAM roles and maps Kubernetes service accounts using IRSA (for least-privilege access).
4. **Security Module** — defines load balancer and pod-level ingress/egress rules.
5. **App Module** — defines app-specific Kubernetes resources and ECR integration.
6. **ALB Controller (Helm)** — deploys the AWS Load Balancer Controller inside the cluster.
7. **Kubernetes Manifests** (`k8s/`) — deploy the example `hello-world` service and deployment.

The result:
A fully functional, Fargate-backed EKS environment accessible via an internet-facing Network Load Balancer (NLB).

---

## 🧩 Repository Structure

```
terraform-aws-eks-microservice-framework/
├── main.tf                      # Root orchestration of all modules
├── variables.tf                 # Global input variables
├── output.tf                    # Exported outputs (VPC IDs, cluster name, etc.)
├── backend.tf                   # Remote state backend (S3 + DynamoDB)
├── alb_controller.tf             # AWS Load Balancer Controller Helm setup
├── Makefile                      # Common commands for Terraform workflows
├── .pre-commit-config.yaml       # Linting, YAML, Terraform & CI validation
├── modules/
│   ├── vpc/                      # Creates subnets, route tables, and VPC
│   ├── eks/                      # Provisions the EKS control plane & Fargate profiles
│   ├── iam/                      # IAM roles for cluster & admin access
│   ├── iam_irsa/                 # IRSA setup for ALB Controller
│   ├── security/                 # Security group & firewall configuration
│   └── app/                      # Placeholder module for app service configuration
├── envs/
│   ├── dev/                      # Environment-specific tfvars
│   ├── test/
│   └── prod/
├── k8s/
│   ├── deployment-hello-world.yaml  # Sample Kubernetes Deployment
│   ├── service-hello-world.yaml     # Sample Service (NLB front-end)
├── docs/
│   └── .gitkeep
├── .github/workflows/ci.yml      # Pre-commit and Terraform CI pipeline
├── LICENSE                       # Apache 2.0 License
└── NOTICE
```

---

## ⚙️ Prerequisites

- Terraform >= 1.6
- AWS CLI configured with admin permissions
- kubectl & eksctl installed
- Helm >= 3.8
- Python >= 3.10 (for pre-commit hooks)
- pre-commit (`pip install pre-commit`)

---

## 🚀 Deployment Steps

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/terraform-aws-eks-microservice-framework.git
cd terraform-aws-eks-microservice-framework
```

### 2. Initialize Terraform

```bash
make init ENV=dev
```

### 3. Plan the Infrastructure

```bash
make plan ENV=dev
```

### 4. Apply the Changes

```bash
make apply ENV=dev
```

### 5. Configure kubectl Access

```bash
aws eks update-kubeconfig --name sample-eks-cluster --region us-east-1
```

### 6. Deploy the Application

```bash
kubectl apply -f k8s/deployment-hello-world.yaml
kubectl apply -f k8s/service-hello-world.yaml
```

After a few minutes, check for the external NLB endpoint:

```bash
kubectl get svc hello-world
```

Then open the URL in a browser — you should see **“Hello World”**.

---

## ✅ Quality & Validation

This repo uses **pre-commit hooks** to enforce code quality before commits.
Run the checks manually using:

```bash
pre-commit run --all-files
```

Checks include:
- Terraform format & validation
- YAML linting
- Kubernetes manifest validation (via kubeconform)
- License header enforcement

---

## 📚 Documentation

Additional guides are available in the [`docs/`](docs/) directory:
- [`docs/architecture.md`](docs/architecture.md) – Visual overview of module interactions.
- [`docs/contributing.md`](docs/contributing.md) – How to extend modules and submit PRs.
- [`docs/troubleshooting.md`](docs/troubleshooting.md) – Common fixes for IAM, NLB, or Fargate issues.

---

## 🪪 License

Licensed under the **Apache License, Version 2.0**.
See the [LICENSE](LICENSE) file for details.

---

## 🧑‍💻 Author

**Darian Lee**
Infrastructure Engineer & Cloud Consultant
[LinkedIn](https://www.linkedin.com/in/darian-873)
