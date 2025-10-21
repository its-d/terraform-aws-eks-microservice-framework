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

# Namespace for Grafana (matches your Fargate selector)
resource "kubernetes_namespace" "monitoring" {
  metadata { name = "monitoring" }
}

# ---- Static EFS volume (Fargate auto-mounts; no driver install needed) ----
resource "kubernetes_persistent_volume" "grafana_pv" {
  metadata { name = "${var.identifier}-grafana-pv" }

  spec {
    capacity                         = { storage = "5Gi" }
    access_modes                     = ["ReadWriteMany"]
    storage_class_name               = "efs-grafana"
    persistent_volume_reclaim_policy = "Delete"

    persistent_volume_source {
      csi {
        driver = "efs.csi.aws.com"
        # Combine FS + AP in the handle; DO NOT use volume_attributes on Fargate
        volume_handle = "${var.efs_file_system_id}::${var.efs_access_point_id}"
      }
    }

    mount_options = ["tls"]
  }
}

# ---- Grafana via Helm ----
resource "helm_release" "grafana" {
  name            = "grafana"
  namespace       = kubernetes_namespace.monitoring.metadata[0].name
  repository      = "https://grafana.github.io/helm-charts"
  chart           = "grafana"
  version         = "8.5.12" # any stable; pin to avoid surprises
  wait            = true
  timeout         = 900
  atomic          = true
  cleanup_on_fail = true

  # persistence: use our existing PVC (EFS)
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
    name  = "ingress.hosts[0]"
    value = ""
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
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/healthcheck-path"
    value = "/api/health"
  }

  # service on 80 → targetPort 3000 (Grafana default)
  set {
    name  = "service.type"
    value = "NodePort"
  }
  set {
    name  = "service.port"
    value = "80"
  }
  set {
    name  = "service.targetPort"
    value = "3000"
  }

  # simple auth (you can move to a secret later)
  set {
    name  = "adminUser"
    value = var.grafana_admin_user
  }
  set {
    name  = "adminPassword"
    value = var.grafana_admin_password
  }

  # ALB ingress
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
  # HTTP only to start; HTTPS later with cert
  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTP\":80}]"
  }

  # basic host-rule-less path
  set {
    name  = "ingress.path"
    value = "/"
  }
}
