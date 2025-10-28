# Grafana module — README

Purpose
- Deploy Grafana into the Kubernetes cluster (namespace `monitoring`) for dashboards and plugins.

What this module provides
- Kubernetes Namespace `monitoring`
- Helm release installation for Grafana
- Optional helper null_resource for small platform-specific fixes

Quick usage (root wiring)
```hcl
module "storage" {
  source                = "./modules/storage"
  identifier            = var.identifier
  private_subnet_ids    = module.vpc.private_subnet_ids
  common_tags           = local.common_tags
}

module "grafana" {
  source                 = "./modules/grafana"
  identifier             = var.identifier
  grafana_admin_user     = var.grafana_admin_user
  grafana_admin_password = var.grafana_admin_password  # recommended: pull from Secrets Manager/SSM
}
```

Inputs & secrets
- grafana_admin_user — string; admin username (recommend storing in Secrets Manager / SSM rather than tfvars).
- grafana_admin_password — sensitive; recommend reading from AWS Secrets Manager or SSM Parameter Store with Terraform data sources.
- identifier — string; naming prefix.

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
- Check Grafana pod logs: `kubectl -n monitoring logs -l app.kubernetes.io/name=grafana`
