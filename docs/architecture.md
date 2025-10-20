# 🏗️ Architecture Overview

This document provides a detailed breakdown of the architecture implemented by the **terraform-aws-eks-microservice-framework**.

---

## 🔧 Core Components

### 1. **VPC Module**
Creates a dedicated AWS VPC with:
- Public and private subnets across multiple Availability Zones.
- Internet and NAT Gateways for public/private routing.
- Route tables and subnet associations.

**Purpose:** Isolates workloads and provides scalable, secure networking.

---

### 2. **EKS Module**
Provisions the **Amazon Elastic Kubernetes Service (EKS)** control plane using Terraform.
This setup is **Fargate-only**, meaning no EC2 worker nodes are required.

Includes:
- EKS Cluster creation.
- Fargate Profiles for `kube-system` and `default` namespaces.
- Cluster authentication and kubeconfig outputs.

**Purpose:** Provides a fully managed Kubernetes control plane and serverless compute.

---

### 3. **IAM Modules**
- **IAM Core:** Handles the creation of cluster and admin roles (EKS cluster, node groups, etc.).
- **IAM IRSA:** Manages *IAM Roles for Service Accounts (IRSA)* to grant specific Kubernetes pods AWS permissions without sharing credentials.

**Purpose:** Implements least-privilege IAM access for Kubernetes workloads and controllers.

---

### 4. **Security Module**
Creates dedicated **Security Groups** and rules for:
- Public NLB ingress (port 80, optional HTTPS).
- Egress to all destinations.
- Optional app-level ingress rules (e.g., port 5678 for `hello-world`).

**Purpose:** Controls network access between external clients, load balancers, and Fargate pods.

---

### 5. **AWS Load Balancer Controller**
Deployed via Helm using Terraform.
Responsible for:
- Automatically provisioning NLBs or ALBs for Kubernetes Services.
- Managing DNS registration and lifecycle.

**Purpose:** Enables native AWS load balancing for Kubernetes services.

---

### 6. **Kubernetes Layer**
Contains the application manifests in `/k8s`:
- `deployment-hello-world.yaml` → A simple HTTP echo app (`hashicorp/http-echo`).
- `service-hello-world.yaml` → Exposes the app publicly via an internet-facing NLB.

**Purpose:** Validates infrastructure and ensures successful Fargate + NLB communication.

---

## 🔄 Data Flow

```
Internet
   │
   ▼
Network Load Balancer (NLB)
   │
   ▼
AWS Security Group (ingress 80 → 5678)
   │
   ▼
Fargate Pod (hello-world)
   │
   ▼
EKS Cluster (managed by Terraform)
   │
   ▼
VPC Subnets / Route Tables
```

---

## 🔐 Security Model

- **IAM IRSA**: Grants AWS permissions to Kubernetes pods using service accounts.
- **Least Privilege**: All IAM policies scoped per service.
- **Network Isolation**: Each environment (dev, prod) can use isolated subnets and SGs.
- **No EC2 dependency**: Fargate abstracts node management and patching.

---

## 📈 Scalability

- Add new services by creating new namespaces and deployments.
- Horizontal scaling handled by Kubernetes’ Deployment autoscaling.
- Additional Fargate profiles can be added per namespace for cost control.

---
