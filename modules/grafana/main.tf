# Copyright 2025 Darian Lee
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

/*
------------------------
* Resource: Grafana Admin and Password Secrets
* Description: Secret for Grafana admin user/password
* Variables:
  - grafana_user_arn
  - grafana_pwd_arn
------------------------
*/
data "aws_secretsmanager_secret_version" "sm_user_version" {
  secret_id = var.grafana_user_arn
}

data "aws_secretsmanager_secret_version" "sm_pwd_version" {
  secret_id = var.grafana_pwd_arn
}

locals {
  grafana_admin_user = sensitive(data.aws_secretsmanager_secret_version.sm_user_version.secret_string)
  grafana_admin_pwd  = sensitive(data.aws_secretsmanager_secret_version.sm_pwd_version.secret_string)
}


/*
-------------------------
* Resource: Kubernetes Namespace
* Description: Creates a Kubernetes namespace for monitoring resources.
* Variables: None
-------------------------
*/
resource "kubernetes_namespace" "monitoring" {
  metadata { name = "monitoring" }
}

/*
-------------------------
* Resource: Helm Release for Grafana
* Description: Deploys Grafana using the official Helm chart with ALB ingress.
* Variables:
  - grafana_admin_user
  - grafana_admin_password
  - region
-------------------------
*/
resource "helm_release" "grafana" {
  name            = "grafana"
  namespace       = kubernetes_namespace.monitoring.metadata[0].name
  repository      = "https://grafana.github.io/helm-charts"
  chart           = "grafana"
  version         = "8.5.12"
  wait            = true
  timeout         = 900
  atomic          = true
  cleanup_on_fail = true

  set {
    name  = "persistence.enabled"
    value = "false"
  }

  set {
    name  = "readinessProbe.enabled"
    value = "true"
  }
  set {
    name  = "readinessProbe.initialDelaySeconds"
    value = "60"
  }
  set {
    name  = "readinessProbe.periodSeconds"
    value = "10"
  }
  set {
    name  = "livenessProbe.enabled"
    value = "true"
  }
  set {
    name  = "livenessProbe.initialDelaySeconds"
    value = "90"
  }
  set {
    name  = "livenessProbe.periodSeconds"
    value = "10"
  }

  set {
    name  = "service.type"
    value = "ClusterIP"
  }
  set {
    name  = "service.port"
    value = "80"
  }
  set {
    name  = "service.targetPort"
    value = "3000"
  }

  set {
    name  = "adminUser"
    value = local.grafana_admin_user
  }
  set {
    name  = "adminPassword"
    value = local.grafana_admin_pwd
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "grafana"
  }

  set {
    name  = "env.AWS_REGION"
    value = var.region
  }

  set {
    name  = "ingress.enabled"
    value = "true"
  }
  set {
    name  = "ingress.ingressClassName"
    value = "alb"
  }
  set {
    name  = "ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "alb"
  }
  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }
  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
    value = var.enable_https ? var.self_signed_certificate_arn : ""
  }
  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = var.enable_https ? "[{\"HTTPS\":443}]" : "[{\"HTTP\":80}]"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/backend-protocol"
    value = "HTTP"
  }
  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/healthcheck-protocol"
    value = "HTTP"
  }

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/healthcheck-path"
    value = "/api/health"
  }

  set {
    name  = "ingress.path"
    value = "/"
  }
  set {
    name  = "ingress.pathType"
    value = "Prefix"
  }

  set {
    name  = "ingress.hosts[0]"
    value = ""
  }

  depends_on = [
    kubernetes_namespace.monitoring,
  ]
}

/*
-------------------------
* Resource: Null Resource to Strip Bad ALB Tags
* Description: Removes invalid tags from the ALB created by the Grafana Helm chart.
* Variables: None
-------------------------
*/
resource "null_resource" "strip_bad_alb_tags" {
  triggers = {
    rel = helm_release.grafana.version
  }
  provisioner "local-exec" {
    command = <<-EOC
      set -euo pipefail
      kubectl -n monitoring annotate ingress grafana alb.ingress.kubernetes.io/tags- || true
    EOC
  }
  depends_on = [helm_release.grafana]
}
