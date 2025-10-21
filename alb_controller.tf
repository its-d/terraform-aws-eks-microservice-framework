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

############################################
# ServiceAccount for ALB Controller (IRSA)
# - Annotated with the IRSA role ARN you already created in module.iam_irsa
############################################
# resource "kubernetes_service_account" "alb_sa" {
#   metadata {
#     name      = "aws-load-balancer-controller"
#     namespace = "kube-system"
#     annotations = {
#       "eks.amazonaws.com/role-arn" = module.iam_irsa.alb_irsa_role_arn
#     }
#     labels = {
#       "app.kubernetes.io/name" = "aws-load-balancer-controller"
#     }
#   }
# }

############################################
# Helm release: AWS Load Balancer Controller
# - Runs in kube-system on Fargate (your Fargate profile has the selector)
# - Uses the ServiceAccount above (so set serviceAccount.create=false)
############################################
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  # Required settings
  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  # Use our pre-created ServiceAccount with IRSA
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam_irsa.alb_irsa_role_arn
  }

  # Helpful default for Fargate; you also set target type per Service via annotation
  set {
    name  = "defaultTargetType"
    value = "ip"
  }

  depends_on = [
    # kubernetes_service_account.alb_sa,
    module.iam_irsa, # IRSA must exist
    module.eks       # cluster must exist
  ]
}
