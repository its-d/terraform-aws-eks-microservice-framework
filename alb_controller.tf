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
# Helm release: AWS Load Balancer Controller
# - Runs in kube-system on Fargate (your Fargate profile has the selector)
# - Uses the ServiceAccount above (so set serviceAccount.create=false)
############################################
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  atomic          = true # succeed-or-rollback in one shot
  wait            = true # wait for all resources to become ready
  cleanup_on_fail = true # delete created resources if install/upgrade fails
  timeout         = 900  # seconds; be generous on first install
  max_history     = 2    # keep history small to avoid clutter

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

  set {
    name  = "defaultTargetType"
    value = "ip"
  }

  depends_on = [
    module.iam_irsa,
    null_resource.write_kubeconfig,
    module.eks
  ]
}
