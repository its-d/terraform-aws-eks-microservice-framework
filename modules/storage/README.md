# Storage (EFS) module — README

Purpose
- Create an Amazon EFS file system, an Access Point configured for Grafana, and mount targets in the cluster's private subnets.
- Expose EFS outputs consumed by the Grafana module and other consumers.

What this module creates
- aws_efs_file_system (encrypted, lifecycle set)
- aws_efs_mount_target resources (one per private subnet)
- aws_efs_access_point with POSIX mapping for Grafana
- Outputs: efs_file_system_id, efs_access_point_id

Quick usage (root wiring)
```hcl
module "storage" {
  source                = "./modules/storage"
  identifier            = var.identifier
  private_subnet_ids    = module.vpc.private_subnet_ids
  efs_security_group_id = module.security.efs_sg_id
  common_tags           = local.common_tags
}
```

Key inputs
- identifier — string; naming prefix.
- private_subnet_ids — list(string); mount targets created in these subnets.
- efs_security_group_id — string; security group used for mount targets (must allow NFS/TCP2049).
- common_tags — map(string).

Key outputs
- efs_file_system_id — string; the created EFS filesystem id.
- efs_access_point_id — string; created access point id used by Grafana.

Operational notes
- The access point is created with POSIX uid/gid values appropriate for Grafana (module defaults may set uid/gid = 472). Adjust if your container runs under a different UID.
- Ensure mount targets are created in subnets accessible to the cluster so pods can mount EFS across AZs.

Troubleshooting
- If mount targets fail or are not reachable: verify `private_subnet_ids` are correct and that the `efs_security_group_id` allows NFS from the cluster SGs.
- If permission problems appear on mount: check the access point POSIX mapping and directory permissions.

Security
- Use security groups to restrict NFS access to the cluster SGs rather than public CIDRs.
