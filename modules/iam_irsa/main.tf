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
* Locals: ALB Controller IRSA
* Description: Local values for the ALB Controller IAM Role for Service Accounts (IRSA).
* Variables:
  - oidc_issuer_url
----------------------------
*/
locals {
  oidc_issuer_host = replace(var.oidc_issuer_url, "https://", "")
  alb_namespace    = "kube-system"
  alb_serviceacct  = "aws-load-balancer-controller"
}

/*
-------------------------
* Data: TLS Certificate for OIDC
* Description: Retrieves the TLS certificate for the OIDC issuer URL.
* Variables:
  - oidc_issuer_url
-------------------------
*/
data "tls_certificate" "eks_oidc" {
  url = var.oidc_issuer_url
}

/*
-------------------------
* Resource: EKS OIDC Provider
* Description: Creates an IAM OIDC provider for the EKS cluster.
* Variables:
  - oidc_issuer_url
  - common_tags
-------------------------
*/
resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  url             = var.oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  tags            = var.common_tags
}

/*
-------------------------
* Data: ALB Controller IRSA Trust Policy
* Description: Creates an IAM policy document for the ALB Controller IAM Role for Service Accounts (IRSA) trust relationship.
* Variables:
  - oidc_issuer_host
  - alb_namespace
  - alb_serviceacct
-------------------------
*/
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

/*
-------------------------
* Resource: ALB Controller IAM Role for Service Accounts (IRSA)
* Description: Creates an IAM role for the ALB Controller with the necessary trust relationship for IRSA.
* Variables:
  - common_tags
-------------------------
*/
resource "aws_iam_role" "alb_irsa" {
  name               = "alb-controller-irsa"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust.json
  tags               = var.common_tags
}

/*
-------------------------
* Resource: ALB Controller IAM Policy Attachment
* Description: Attaches the necessary IAM policy to the ALB Controller IAM Role for Service Accounts (IRSA).
* Variables: None
-------------------------
*/
resource "aws_iam_policy" "alb_controller" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/policies/aws_load_balancer_controller_iam_policy.json")
}

/*
-------------------------
* Resource: ALB Controller IAM Role Policy Attachment
* Description: Attaches the ALB Controller IAM policy to the ALB Controller IAM Role for Service Accounts (IRSA).
* Variables: None
-------------------------
*/
resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_irsa.name
  policy_arn = aws_iam_policy.alb_controller.arn
}
