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

# modules/iam_irsa/outputs.tf

output "alb_irsa_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller"
  value       = aws_iam_role.alb_irsa.arn
}

output "aws_iam_openid_connect_provider" {
  description = "IAM OIDC provider for the EKS cluster"
  value       = aws_iam_openid_connect_provider.eks_oidc_provider
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.eks_oidc_provider.arn
}


output "oidc_issuer_host" {
  description = "OIDC issuer host for the EKS cluster"
  value       = replace(var.oidc_issuer_url, "https://", "")
}
