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

# modules/iam_irsa/main.tf
# Post-cluster IAM: OIDC provider + AWS Load Balancer Controller IRSA

variable "common_tags" {
  type        = map(string)
  description = "Common tags"
  default     = {}
}

variable "identifier" {
  type        = string
  description = "Name prefix / identifier"
}

variable "oidc_issuer_url" {
  type        = string
  description = "EKS cluster OIDC issuer URL (from module.eks.oidc_issuer_url)"
}

locals {
  oidc_issuer_host = replace(var.oidc_issuer_url, "https://", "")
  alb_namespace    = "kube-system"
  alb_serviceacct  = "aws-load-balancer-controller"
}

# OIDC provider
data "tls_certificate" "eks_oidc" {
  url = var.oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  url             = var.oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  tags            = var.common_tags
}

# IRSA trust scoped to ALB Controller SA
data "aws_iam_policy_document" "irsa_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks_oidc_provider.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:${local.alb_namespace}:${local.alb_serviceacct}"]
    }
  }
}

resource "aws_iam_role" "alb_irsa" {
  name               = "${var.identifier}-alb-controller-irsa"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust.json
  tags               = var.common_tags
}

# ALB Controller policy (JSON file in this module)
resource "aws_iam_policy" "alb_controller" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/policies/aws_load_balancer_controller_iam_policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_irsa.name
  policy_arn = aws_iam_policy.alb_controller.arn
}
