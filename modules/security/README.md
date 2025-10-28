# Security module — README

Purpose
- Define and manage security groups and network-level rules used across the platform: EKS cluster, load balancers, and application-level traffic rules.

What this module provides
- Security group for EKS cluster ENIs (cluster SG)
- Security group rules for load balancers to reach pod ports (as needed)
- Outputs used by storage and other modules

Quick usage (root wiring)
```hcl
module "security" {
  source                    = "./modules/security"
  vpc_id                    = module.vpc.vpc_id
  cluster_security_group_id = module.eks.cluster_security_group_id
  common_tags               = local.common_tags
}
```

Key inputs
- vpc_id — string; VPC identifier for scoping SGs.
- cluster_security_group_id — string; EKS cluster SG reference.
- common_tags — map(string).

Key outputs
- any other SG IDs created for platform use.

Operational guidance
- Use Security Group references (source by SG id) rather than wide CIDRs where possible.
- Tag SGs for traceability.
