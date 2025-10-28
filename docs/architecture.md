# Architecture/System Configuration

---

## Core Components & Responsibilities

1. VPC Module
   - Creates a VPC with public/private subnets across AZs.
   - NAT gateways, route tables, and subnet associations.
   - Produces subnet IDs consumed by EKS or other modules.

2. EKS Module
   - Creates the EKS control plane (managed by AWS).
   - Uses Fargate profiles to run pods serverless (no EC2 nodegroups by default).
   - Outputs kubeconfig and cluster details that operators use with kubectl.

3. IAM / IRSA Modules
   - Create IAM roles and policies needed by the cluster.
   - Configure IRSA (IAM Roles for Service Accounts) for controllers such as the AWS Load Balancer Controller and Grafana.
   - Keeps permissions scoped to the minimum needed.

4. Security Module
   - Creates security groups used by load balancers and pods.
   - Defines ingress/egress rules used by the NLB/ALB and application ports.

5. AWS Load Balancer Controller (Helm via Terraform)
   - Deploys controller that converts Kubernetes Service/Ingress resources into AWS ELB resources (ALB/NLB).
   - Uses IRSA for permissions to manage ELB resources.

6. Monitoring: Grafana (Ready-to-use)
   - Grafana is deployed as part of the stack.

---

## Data Flow

Internet -> NLB (or ALB) -> Security Group -> Fargate Pod -> EKS Control Plane -> AWS Services

- The AWS Load Balancer Controller observes Services/Ingress in Kubernetes and creates the corresponding AWS load balancer resources (target groups, listeners).
- Fargate pods use ENIs for networking; these ENIs live in your VPC and can prevent deletion of VPC/subnet resources if not removed first.

---

## Resilience & Security Patterns

- IRSA for least-privilege pod permissions.
- Separate environments via `env/<env>/terraform.tfvars`.
- Remote state via S3 and DynamoDB (locking) to prevent concurrent modifications.

---

## Extending the Architecture

- Add additional Fargate profiles per namespace for cost separation.
- Add node groups (EC2) if workloads require host-level access or special drivers.
- Add service mesh or ingress controller if you need L7 routing features not provided by NLB.

---
