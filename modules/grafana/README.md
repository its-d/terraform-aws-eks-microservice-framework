# Grafana module — README

Purpose
- Deploy Grafana into the Kubernetes cluster (namespace `monitoring`) for dashboards and plugins.

What this module provides
- Kubernetes Namespace `monitoring`
- Helm release installation for Grafana
- Optional helper null_resource for small platform-specific fixes

Quick usage (root wiring)
```hcl
module "grafana" {
  source                      = "./modules/grafana"
  region                      = var.region
  grafana_user_arn            = var.grafana_admin_user_arn
  grafana_pwd_arn             = var.grafana_admin_pwd_arn
  self_signed_certificate_arn = var.self_signed_certificate_arn
  enable_https                = var.enable_https
}
```

Inputs & secrets
- grafana_user_arn — ARN of the Secrets Manager secret storing the Grafana admin username.
- grafana_pwd_arn — ARN of the Secrets Manager secret storing the Grafana admin password.
- region — AWS region.
- self_signed_certificate_arn — ARN of the TLS certificate for ALB (when enable_https is true).
- enable_https — bool; enable HTTPS on the Grafana ingress.

Secrets recommendation (already adopted)
- Store admin credentials in AWS Secrets Manager. Reference via ARNs in tfvars. Do not hardcode in tfvars.

Troubleshooting
- Check Grafana pod logs: `kubectl -n monitoring logs -l app.kubernetes.io/name=grafana`
