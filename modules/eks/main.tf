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
* Resource: EKS CoreDNS Addon Patch for Fargate
* Description: Configures the CoreDNS addon to run on Fargate nodes.
* Variables required: None
----------------------------
*/
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "coredns"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    nodeSelector = {
      "eks.amazonaws.com/compute-type" = "fargate"
    }
    tolerations = [{
      key      = "eks.amazonaws.com/compute-type"
      operator = "Equal"
      value    = "fargate"
      effect   = "NoSchedule"
    }]
  })

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_fargate_profile.fargate_profile
  ]
}
