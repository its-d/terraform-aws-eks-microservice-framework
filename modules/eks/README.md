# EKS module — README

Purpose
- Provision the Amazon EKS control plane and Fargate profiles required to run Kubernetes workloads with minimal operational overhead.
- Expose cluster metadata required by downstream modules (cluster name, cluster security group ID, OIDC issuer URL for IRSA).

What this module provides
- aws_eks_cluster resource
- aws_eks_fargate_profile resource(s) for selected namespaces
- A small create-time helper that attempts to update local kubeconfig and patch CoreDNS for Fargate scheduling (runs only on initial create)
- Outputs: cluster_name, cluster_security_group_id, oidc_issuer_url, and other cluster metadata

Important: kubeconfig & post-create behavior (safe-by-default)
- On initial resource creation, the module runs a local create-time provisioner that:
  - Attempts to add the new cluster to the local kubeconfig using `aws eks update-kubeconfig` (only if the cluster is not already present in kubeconfig).
  - Attempts to patch the CoreDNS deployment (in kube-system) so it can schedule on Fargate (adds nodeSelector/tolerations) and waits for rollout (with a timeout). Non-fatal issues are logged as warnings.
- The create-time provisioner runs exactly once (when Terraform creates the cluster resource). It will not run for normal subsequent `terraform apply` calls.

Quick usage (root wiring)
```hcl
module "eks" {
  source                = "./modules/eks"
  identifier            = var.identifier
  private_subnet_ids    = module.vpc.private_subnet_ids
  cluster_role_arn      = module.iam.eks_cluster_role_arn
  pod_execution_role_arn = module.iam.pod_execution_role_arn
  common_tags           = local.common_tags
}
```

Key inputs (high level)
- identifier — string; prefix for resource names.
- private_subnet_ids — list(string); subnets for control plane ENIs and Fargate.
- cluster_role_arn — string; IAM role ARN for the EKS control plane.
- pod_execution_role_arn — string; pod execution role used by Fargate pods (IRSA).
- public_access_cidrs — list(string); allowed CIDRs if public access enabled.

Key outputs
- cluster_name — the EKS cluster name (useful for aws eks update-kubeconfig).
- cluster_security_group_id — security group ID used by the cluster (useful for SG rules).
- oidc_issuer_url — OIDC issuer URL for configuring IRSA.

Requirements & providers
- Terraform >= 1.5.0
- AWS provider ~> 5.95
- null provider ~> 3.2 (used for optional local steps)

Troubleshooting
- If kubeconfig update fails: ensure `aws` CLI is installed and credentials are available.
- If CoreDNS rollout does not complete: inspect pod logs in kube-system and the EKS control plane events.
