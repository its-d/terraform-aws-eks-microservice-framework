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

# modules/iam/main.tf
# Core IAM: (1) EKS cluster role  (2) Fargate pod execution role
# No OIDC or ALB IRSA here (those go to modules/iam_irsa after cluster exists)

# ----------------------------
# EKS cluster role (control plane)
# ----------------------------
data "aws_iam_policy_document" "eks_cluster_iam_policy_document" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
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

# ----------------------------
# Fargate pod execution role
# ----------------------------
data "aws_iam_policy_document" "eks_pod_execution_role_iam_policy_document" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_pod_execution_role" {
  name               = "eks_pod_execution_role"
  assume_role_policy = data.aws_iam_policy_document.eks_pod_execution_role_iam_policy_document.json
  tags               = var.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_pod_AmazonEKSFargatePodExecutionRolePolicy" {
  role       = aws_iam_role.eks_pod_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

# Optional only if you run CloudWatch Agent
resource "aws_iam_role_policy_attachment" "eks_pod_CloudWatchAgentServerPolicy" {
  role       = aws_iam_role.eks_pod_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
