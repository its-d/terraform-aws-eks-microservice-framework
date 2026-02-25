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

/*
----------------------------
* Resources: ALB Controller IRSA
* Description: IAM Role and Policy for the AWS Load Balancer Controller using IRSA.
* Variables:
  - oidc_provider_arn
  - common_tags
----------------------------
*/
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


/*
----------------------------
* Resource: ALB Controller IAM Policy and Attachment
* Description: IAM Policy and Attachment for the AWS Load Balancer Controller.
* Variables: None
----------------------------
*/
resource "aws_iam_policy" "alb_controller" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/policies/aws_load_balancer_controller_iam_policy.json")
}

/*
----------------------------
* Resource: ALB Controller IAM Role Policy Attachment
* Description: Attaches the IAM Policy to the ALB Controller IRSA Role.
* Variables: None
----------------------------
*/
resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_irsa.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

/*
----------------------------
* Grafana IRSA for CloudWatch
* Description: IAM Role for Grafana to query CloudWatch Logs and Metrics via IRSA.
----------------------------
*/
locals {
  grafana_sa_namespace = "monitoring"
  grafana_sa_name      = "grafana"
  grafana_sa_subject   = "system:serviceaccount:${local.grafana_sa_namespace}:${local.grafana_sa_name}"
}

resource "aws_iam_role" "grafana_irsa" {
  name = "grafana-cloudwatch-irsa"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = var.oidc_provider_arn }
      Condition = {
        StringEquals = {
          "${local.issuer_host}:aud" = "sts.amazonaws.com"
          "${local.issuer_host}:sub" = local.grafana_sa_subject
        }
      }
    }]
  })
  tags = var.common_tags
}

resource "aws_iam_policy" "grafana_cloudwatch" {
  name   = "GrafanaCloudWatchPolicy"
  policy = file("${path.module}/policies/grafana_cloudwatch_iam_policy.json")
}

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  role       = aws_iam_role.grafana_irsa.name
  policy_arn = aws_iam_policy.grafana_cloudwatch.arn
}
