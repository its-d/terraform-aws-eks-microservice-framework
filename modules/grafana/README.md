# Grafana module — README

Purpose
- Deploy Grafana into the Kubernetes cluster (namespace `monitoring`) and provide a persistent volume backed by EFS for dashboards, plugins, and other persisted state.

What this module provides
- Kubernetes Namespace `monitoring`
- Kubernetes PersistentVolume (EFS-backed) and PersistentVolumeClaim
- Helm release installation for Grafana
- Optional helper null_resource for small platform-specific fixes

Important: default wiring for EFS
- In the repository's root `main.tf`, the `storage` module creates the EFS file system and access point. The root module wires `module.storage` outputs into this Grafana module by default (see root main.tf).
- Default usage: do not set `efs_file_system_id` or `efs_access_point_id` in env tfvars — let the root module create and pass them. If you want to reuse an external EFS, this module accepts EFS IDs (advanced flow).

Quick usage (root wiring)
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
  grafana_admin_user     = var.grafana_admin_user
  grafana_admin_password = var.grafana_admin_password  # recommended: pull from Secrets Manager/SSM
}
```

Inputs & secrets
- grafana_admin_user — string; admin username (recommend storing in Secrets Manager / SSM rather than tfvars).
- grafana_admin_password — sensitive; recommend reading from AWS Secrets Manager or SSM Parameter Store with Terraform data sources.
- identifier — string; naming prefix.
- efs_file_system_id / efs_access_point_id — strings (when reusing external EFS).

Outputs (suggested)
- grafana_pvc_name — name of created PVC.
- grafana_pv_name — name of created PV.
- efs_file_system_id / efs_access_point_id — passthrough or linked values.

Secrets recommendation (already adopted)
- Retrieve admin credentials from AWS Secrets Manager or SSM, e.g.:
```hcl
data "aws_ssm_parameter" "grafana_admin_password" {
  name           = "/project/${var.environment}/grafana_admin_password"
  with_decryption = true
}
```
- Do not hardcode sensitive values into env tfvars; prefer CI secret injection or Secrets Manager.

Troubleshooting
- If PVC remains Pending: ensure `efs_file_system_id` exists, mount targets exist in the cluster subnets, and `efs_security_group_id` allows TCP/2049 from the cluster SG.
- Check Grafana pod logs: `kubectl -n monitoring logs -l app.kubernetes.io/name=grafana`
- Validate PV/PVC binding with kubectl:
  - `kubectl get pv`
  - `kubectl get pvc -n monitoring`
