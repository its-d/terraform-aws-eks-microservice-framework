# Grafana module — README (updated)

This module deploys Grafana into the Kubernetes cluster (namespace `monitoring`) and mounts persistent storage for Grafana data via EFS (PersistentVolume / PersistentVolumeClaim).

Important: default repository wiring
- In the repository's default root configuration (`main.tf`) the `modules/storage` module **creates** the EFS File System, Access Point, and mount targets.
- The root module then passes `module.storage.efs_file_system_id` and `module.storage.efs_access_point_id` into this Grafana module.
- That means, in the default workflow, you do **not** need to provide `efs_file_system_id` or `efs_access_point_id` in your env tfvars — they are produced and wired by the root module.

If you open this module in isolation (e.g., to reuse it elsewhere), see the "Using module in isolation" section below.

What this module creates (when configured by the root)
- Kubernetes namespace `monitoring`
- Kubernetes PersistentVolume (EFS-backed)
- Kubernetes PersistentVolumeClaim bound to the PV
- Helm release for Grafana (the chart is installed into the `monitoring` namespace)
- Optional null_resource `strip_bad_alb_tags` to handle ALB tag oddities (repo-specific)

Inputs (high level)
- `identifier` (string) — unique prefix for resource names
- `region` (string) — AWS region (used as needed)
- `grafana_admin_user` (string) — Grafana admin username
- `grafana_admin_password` (string, sensitive) — Grafana admin password
- `efs_file_system_id` (string, optional) — EFS FS ID to use (default: provided by root via `module.storage`)
- `efs_access_point_id` (string, optional) — EFS Access Point ID (default: provided by root via `module.storage`)

Default behavior (recommended)
- Use the repository default: let the root module create and manage EFS via `modules/storage`.
  - This avoids confusion and ensures mount targets/security groups are created consistently with the VPC.
  - After `terraform apply` you can inspect the EFS IDs with `terraform output efs_file_system_id` and `terraform output efs_access_point_id` at the root.

Using the module in isolation (advanced)
- If you want to reuse this Grafana module with an externally-managed EFS:
  1. Provide `efs_file_system_id` and `efs_access_point_id` variables when calling the module.
  2. Ensure mount targets and a compatible security group exist in the cluster VPC that allow NFS (TCP/2049) from the cluster ENIs.
  3. Ensure the Access Point is configured with POSIX user mapping compatible with Grafana (UID/GID used in the PV).

Examples

A) Default repository usage (root `main.tf` wires storage → grafana):
```hcl
module "storage" {
  source                = "./modules/storage"
  identifier            = var.identifier
  private_subnet_ids    = module.vpc.private_subnet_ids
  efs_security_group_id = module.security.efs_sg_id
  common_tags           = local.common_tags
}

module "grafana" {
  source                 = "./modules/grafana"
  identifier             = var.identifier
  efs_file_system_id     = module.storage.efs_file_system_id
  efs_access_point_id    = module.storage.efs_access_point_id
  grafana_admin_password = var.grafana_admin_password
  grafana_admin_user     = var.grafana_admin_user
}
```

B) Using module with an external EFS (advanced):
```hcl
module "grafana" {
  source                 = "git::https://github.com/its-d/terraform-aws-eks-microservice-framework.git//modules/grafana?ref=final-touches"
  identifier             = "myproj"
  efs_file_system_id     = "fs-0123456789abcdef0"   # external FS id
  efs_access_point_id    = "fsap-0123456789abcdef0" # external access point
  grafana_admin_password = var.grafana_admin_password
  grafana_admin_user     = var.grafana_admin_user
}
```

Outputs (useful to expose after apply)
- `efs_file_system_id` — the EFS file system ID used by Grafana (pass-through of provided or root-generated value)
- `efs_access_point_id` — the EFS access point ID used by Grafana
- `grafana_pvc_name` — the PersistentVolumeClaim name created for Grafana
- `grafana_pv_name` — the PersistentVolume name created for Grafana
- `grafana_helm_release` — helm_release.grafana.name (useful to inspect helm status)

Troubleshooting tips
- If PVC stays `Pending`, confirm `efs_file_system_id` and mount targets exist in the VPC & subnets, and that SG rules allow TCP/2049 from the cluster ENIs.
- Check Grafana pod logs: `kubectl -n monitoring logs -l app.kubernetes.io/name=grafana`
- Validate PV/PVC binding:
  - `kubectl get pv -n monitoring`
  - `kubectl get pvc -n monitoring`
