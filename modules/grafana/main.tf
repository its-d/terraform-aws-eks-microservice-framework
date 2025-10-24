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

# -------------------------
# Resource: Kubernetes Namespace
# Description: Creates a Kubernetes namespace for monitoring resources.
# Variables:
# - efs_file_system_id
# - efs_access_point_id
# -------------------------
resource "kubernetes_namespace" "monitoring" {
  metadata { name = "monitoring" }
}

# -------------------------
# Resource: Kubernetes Persistent Volume for Grafana
# Description: Creates a Persistent Volume on EFS for Grafana data storage.
# Variables:
# - efs_file_system_id
# - efs_access_point_id
# -------------------------
resource "kubernetes_persistent_volume" "grafana_pv" {
  metadata { name = "${var.identifier}-grafana-pv" }

  spec {
    capacity                         = { storage = "5Gi" } # logical; EFS is elastic
    access_modes                     = ["ReadWriteMany"]
    storage_class_name               = "efs-grafana" # just a label to match the PVC
    persistent_volume_reclaim_policy = "Retain"      # keep data if PVC/Release is removed

    persistent_volume_source {
      csi {
        driver        = "efs.csi.aws.com"
        volume_handle = "${var.efs_file_system_id}::${var.efs_access_point_id}"
      }
    }

    mount_options = ["tls"]
  }
}

# -------------------------
# Resource: Kubernetes Persistent Volume Claim for Grafana
# Description: Claims the Persistent Volume for Grafana usage.
# Variables:
# - identifier
# -------------------------
resource "kubernetes_persistent_volume_claim" "grafana_pvc" {
  metadata {
    name      = "${var.identifier}-grafana-pvc"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "efs-grafana"
    resources { requests = { storage = "5Gi" } }
    volume_name = kubernetes_persistent_volume.grafana_pv.metadata[0].name
  }
}

# -------------------------
# Resource: Helm Release for Grafana
# Description: Deploys Grafana using the official Helm chart with EFS persistence and ALB ingress.
# Variables:
# - grafana_admin_user
# - grafana_admin_password
# - region
# -------------------------

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
    value = "true"
  }
  set {
    name  = "persistence.existingClaim"
    value = kubernetes_persistent_volume_claim.grafana_pvc.metadata[0].name
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
    value = var.grafana_admin_user
  }
  set {
    name  = "adminPassword"
    value = var.grafana_admin_password
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
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }
  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }
  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTP\":80}]"
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

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_persistent_volume.grafana_pv,
    kubernetes_persistent_volume_claim.grafana_pvc
  ]
}

# -------------------------
# Resource: Null Resource to Strip Bad ALB Tags
# Description: Removes invalid tags from the ALB created by the Grafana Helm chart.
# Variables: None
# -------------------------
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
