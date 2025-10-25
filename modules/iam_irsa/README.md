# IAM IRSA module — README

Purpose
- Configure IAM Roles for Service Accounts (IRSA) so Kubernetes workloads (controllers like the AWS Load Balancer Controller) can assume least-privilege AWS permissions without embedded keys.

What this module provides
- IAM role(s) with trust policies bound to the EKS OIDC provider
- Optional inline/managed policies scoped to the controller's needs (e.g., ELB actions, SSM/EFS access)
- Guidance for annotating Kubernetes service accounts to use the created roles

Quick usage (root wiring)
```hcl
module "iam_irsa" {
  source        = "./modules/iam_irsa"
  oidc_issuer_url = module.eks.oidc_issuer_url
  common_tags   = local.common_tags
}
```

Key inputs
- oidc_issuer_url — string; the EKS cluster OIDC issuer URL from module.eks.
- common_tags — map(string).

Key outputs
- role ARNs for created IRSA roles (e.g., aws_load_balancer_controller_role_arn).

How to use with Kubernetes
- Annotate the controller's service account:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: "<role-arn-from-terraform>"
```

Security & best practices
- Scope IAM policies to specific resource ARNs rather than using broad wildcards.
- Keep role names and tags consistent to ease discovery and audits.

Troubleshooting
- If pods cannot assume the role: check the OIDC provider, trust relationship, and that the service account annotation matches the expected role ARN.
