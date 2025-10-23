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

6. Monitoring: Grafana backed by EFS (Ready-to-use)
   - Grafana is deployed as part of the stack and can be backed by an EFS file system and access point.
   - EFS provides persistent storage for Grafana configuration, dashboards, plugins, and data that must survive pod restarts and cluster reprovisioning.
   - Integration is done via a Kubernetes PersistentVolumeClaim that mounts an EFS-backed PersistentVolume — the module expects `efs_file_system_id` and `efs_access_point_id` tfvars if you want to enable this.
   - Security: EFS mount targets must be reachable from cluster networking and SG rules must allow NFS (TCP/2049) traffic.

---

## Data Flow

Internet -> NLB (or ALB) -> Security Group -> Fargate Pod -> EKS Control Plane -> AWS Services

- The AWS Load Balancer Controller observes Services/Ingress in Kubernetes and creates the corresponding AWS load balancer resources (target groups, listeners).
- Fargate pods use ENIs for networking; these ENIs live in your VPC and can prevent deletion of VPC/subnet resources if not removed first.
- Grafana connects to EFS via mount targets in the VPC; the mount occurs from pods so EFS must be in the same VPC or peered network.

---

## Resilience & Security Patterns

- IRSA for least-privilege pod permissions.
- Separate environments via `env/<env>/terraform.tfvars`.
- Remote state via S3 and DynamoDB (locking) to prevent concurrent modifications.
- EFS with Access Points to isolate Grafana data and use POSIX user mapping for secure mounts.

---

## Extending the Architecture

- Add additional Fargate profiles per namespace for cost separation.
- Add node groups (EC2) if workloads require host-level access or special drivers.
- Add service mesh or ingress controller if you need L7 routing features not provided by NLB.

---
