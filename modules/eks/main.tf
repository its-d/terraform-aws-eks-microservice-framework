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
----------------------------
* Resource: EKS Cluster
* Description: Creates an EKS cluster with specified configuration.
* Variables required:
  - identifier
  - cluster_role_arn
  - pod_execution_role_arn
  - private_subnet_ids
  - endpoint_private_access
  - common_tags
----------------------------
*/
resource "aws_eks_cluster" "eks_cluster" {
  name     = "${var.identifier}-eks-cluster"
  role_arn = var.cluster_role_arn
  version  = "1.34"

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  tags = var.common_tags
}

/*
----------------------------
* Resource: EKS Fargate Profile
* Description: Creates an EKS Fargate profile to run pods in specified namespaces on Fargate.
* Variables required:
  - identifier
  - pod_execution_role_arn
  - private_subnet_ids
  - common_tags
----------------------------
*/
resource "aws_eks_fargate_profile" "fargate_profile" {
  cluster_name           = aws_eks_cluster.eks_cluster.name
  fargate_profile_name   = "${var.identifier}-fargate-profile"
  pod_execution_role_arn = var.pod_execution_role_arn
  subnet_ids             = var.private_subnet_ids

  selector {
    namespace = "default"
  }

  selector {
    namespace = "monitoring"
  }

  selector {
    namespace = "kube-system"
    labels = {
      k8s-app = "kube-dns"
    }
  }

  selector {
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
    }
  }

  tags = var.common_tags
}

/*
----------------------------
* Resource: Patch CoreDNS Deployment for Fargate
* Description: Patches the CoreDNS deployment to run on Fargate by adding the necessary nodeSelector and tolerations.
* Variables required:
  - region
----------------------------
*/
resource "null_resource" "patch_coredns_fargate" {
  triggers = {
    cluster_endpoint = aws_eks_cluster.eks_cluster.endpoint
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_fargate_profile.fargate_profile
  ]

  provisioner "local-exec" {
    command = <<-EOC
      set -euo pipefail
      aws eks update-kubeconfig --name ${aws_eks_cluster.eks_cluster.name} --region ${var.region}
      kubectl -n kube-system patch deployment coredns \
        -p '{
          "spec": {
            "template": {
              "spec": {
                "nodeSelector": {"eks.amazonaws.com/compute-type":"fargate"},
                "tolerations": [{
                  "key":"eks.amazonaws.com/compute-type",
                  "operator":"Equal",
                  "value":"fargate",
                  "effect":"NoSchedule"
                }]
              }
            }
          }
        }'
      kubectl -n kube-system rollout status deploy/coredns --timeout=120s
    EOC
  }
}
