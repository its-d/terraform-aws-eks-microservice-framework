# IAM core module — README

Purpose
- Create IAM roles, policies, and service principals required to operate the EKS cluster and platform components (cluster control plane role, pod-execution role, CI role recommendations).
- Provide least-privilege IAM artifacts consumed by other modules.

What this module provides (typical)
- IAM role(s) for the EKS control plane (if created here)
- Pod execution role ARN used by Fargate / IRSA flows
- Optional managed/inline policies required by platform components
- Outputs referencing role ARNs used by EKS module and other modules

Quick usage (root wiring)
```hcl
module "iam" {
  source      = "./modules/iam"
  identifier  = var.identifier
  common_tags = local.common_tags
}
```

Key inputs
- identifier — string; prefix for role names.
- common_tags — map(string); tags applied to IAM resources.

Key outputs (examples)
- eks_cluster_role_arn — ARN of the EKS control plane role (if created here).
- pod_execution_role_arn — ARN for pod-execution (IRSA) role.

Security & best practices
- Scope policies to least privilege; avoid `*` where possible.
- For CI/automation, create a narrowly scoped role with S3/DynamoDB state privileges plus limited EKS actions. Provide an example policy in docs (recommended).

Troubleshooting
- AccessDenied errors: check the policy attachments and trust relationships for roles being assumed by EKS or CI agents.
