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

module "cluster_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = ">= 6.2.1"

  name = "eks_cluster_role"

  trust_policy_permissions = {
    TrustRoleAndServiceToAssume = {
      principals = [{
        type = "Service"
        identifiers = [
          "eks.amazonaws.com",
        ]
      }]
      condition = []
    }
  }

  policies = {
    AmazonEKSClusterPolicy          = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    AmazonEKS_VPCResourceController = "arn:aws:iam::aws:policy/AmazonEKS_VPCResourceController"
  }

  tags = var.common_tags
}

# module "node_role" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-role"

#   name = "example"

#   trust_policy_permissions = {
#     TrustRoleAndServiceToAssume = {
#       principals = [{
#         type = "AWS"
#         identifiers = [
#           "arn:aws:iam::835367859851:user/anton",
#         ]
#       }]
#       condition = [{
#         test     = "StringEquals"
#         variable = "sts:ExternalId"
#         values   = ["some-secret-id"]
#       }]
#     }
#   }

#   policies = {
#     AmazonCognitoReadOnly      = "arn:aws:iam::aws:policy/AmazonCognitoReadOnly"
#     AlexaForBusinessFullAccess = "arn:aws:iam::aws:policy/AlexaForBusinessFullAccess"
#     custom                     = aws_iam_policy.this.arn
#   }

#   tags = var.common_tags
# }

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
