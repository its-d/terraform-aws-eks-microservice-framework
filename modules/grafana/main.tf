# Copyright 2025 Darian Lee
#
# Licensed under the Apache License, Version 2.0 (the "License");
# ...

# Namespace for Grafana (matches your Fargate selector)
resource "kubernetes_namespace" "monitoring" {
  metadata { name = "monitoring" }
}

# ---- Static EFS volume for Fargate (CSI, using FS::AP handle) ----
# NOTE: On Fargate, do NOT use volume_attributes. The handle must be "<fs-id>::<ap-id>"
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

# ---- Grafana via Helm ----
resource "helm_release" "grafana" {
  name            = "grafana"
  namespace       = kubernetes_namespace.monitoring.metadata[0].name
  repository      = "https://grafana.github.io/helm-charts"
  chart           = "grafana"
  version         = "8.5.12" # pin for reproducibility
  wait            = true
  timeout         = 900
  atomic          = true
  cleanup_on_fail = true

  # --- Persistence ON: bind to our existing PVC on EFS ---
  set {
    name  = "persistence.enabled"
    value = "true"
  }
  set {
    name  = "persistence.existingClaim"
    value = kubernetes_persistent_volume_claim.grafana_pvc.metadata[0].name
  }

  # The official Grafana image runs as UID/GID 472 by default, which matches your EFS AP.
  # No need to change runAsUser/fsGroup here.

  # --- Probes (give Grafana a moment to boot) ---
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

  # --- Service (use ClusterIP; ALB will target pod IPs) ---
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

  # --- Admin auth (move to secret later if you want) ---
  set {
    name  = "adminUser"
    value = var.grafana_admin_user
  }
  set {
    name  = "adminPassword"
    value = var.grafana_admin_password
  }

  # --- IRSA: let Grafana read CloudWatch later without static creds ---
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

  # --- ALB Ingress (no host -> wildcard *) ---
  set {
    name  = "ingress.enabled"
    value = "true"
  }
  set {
    name  = "ingress.ingressClassName"
    value = "alb"
  }
  # Keep legacy annotation too (some setups still read it)
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

  # Make sure the PV/PVC exist before Helm tries to mount
  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_persistent_volume.grafana_pv,
    kubernetes_persistent_volume_claim.grafana_pvc
  ]
}

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
