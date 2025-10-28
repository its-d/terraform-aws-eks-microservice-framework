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
  - oidc_provider_arn
  - common_tags
----------------------------
*/

locals {
  issuer_host  = replace(var.oidc_issuer_url, "https://", "")
  sa_namespace = "kube-system"
  sa_name      = "aws-load-balancer-controller"
  sa_subject   = "system:serviceaccount:${local.sa_namespace}:${local.sa_name}"
}

resource "aws_iam_role" "alb_irsa" {
  name = "alb-controller-irsa"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = var.oidc_provider_arn }
      Condition = {
        StringEquals = {
          "${local.issuer_host}:aud" = "sts.amazonaws.com"
          "${local.issuer_host}:sub" = local.sa_subject
        }
      }
    }]
  })
  tags = var.common_tags
}

# Use the official policy JSON you already have in repo
resource "aws_iam_policy" "alb_controller" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/policies/aws_load_balancer_controller_iam_policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_irsa.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

output "alb_irsa_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller"
  value       = aws_iam_role.alb_irsa.arn
}
