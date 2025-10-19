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

# module "eks_oidc" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-oidc-provider"

#   url = data.aws_eks_cluster.cluster.identity[0].oidc.issuer

#   tags = var.common_tags
# }


data "aws_iam_policy_document" "eks_cluster_iam_policy_document" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]

  }

}

resource "aws_iam_role" "eks_cluster_role" {
  name               = "eks_cluster_role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_iam_policy_document.json
  tags               = var.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKS_VPCResourceController" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_VPCResourceController"

}

data "aws_iam_policy_document" "eks_pod_execution_role_iam_policy_document" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }

}

resource "aws_iam_role" "eks_pod_execution_role" {
  name               = "eks_pod_execution_role"
  assume_role_policy = data.aws_iam_policy_document.eks_pod_execution_role_iam_policy_document.json
  tags               = var.common_tags
}


resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKSFargatePodExecutionRolePolicy" {
  role       = aws_iam_role.eks_pod_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_CloudWatchAgentServerPolicy" {
  role       = aws_iam_role.eks_pod_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"

}


# module "alb_controller_irsa" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"

#   name = "vpc-cni"

#   attach_vpc_cni_policy = true
#   vpc_cni_enable_ipv4   = true

#   oidc_providers = {
#     this = {
#       provider_arn               = "arn:aws:iam::012345678901:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/5C54DDF35ER19312844C7333374CC09D"
#       namespace_service_accounts = ["kube-system:aws-node"]
#     }
#   }

#   tags = var.common_tags
# }
