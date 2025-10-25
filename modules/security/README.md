# Security module — README

Purpose
- Define and manage security groups and network-level rules used across the platform: EKS cluster, EFS mount targets, load balancers, and application-level traffic rules.

What this module provides
- Security group for EKS cluster ENIs (cluster SG)
- Security group for EFS mount targets (`efs_sg_id`) and appropriate NFS rules
- Security group rules for load balancers to reach pod ports (as needed)
- Outputs used by storage and other modules (e.g., efs_sg_id)

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
- efs_sg_id — security group to attach to EFS mount targets (must allow TCP/2049 from cluster ENIs).
- any other SG IDs created for platform use.

Operational guidance
- Use Security Group references (source by SG id) rather than wide CIDRs where possible.
- Tag SGs for traceability.

Troubleshooting
- If EFS mounts fail: ensure `efs_sg_id` allows inbound TCP/2049 from the cluster security group or the pod ENI SGs, and that mount targets exist in the required subnets/AZs.
