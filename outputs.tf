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

output "region" {
  description = "AWS region"
  value       = var.region
}

# -------- EKS (from modules/eks wrapper) --------
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "oidc_issuer_url" {
  description = "EKS OIDC issuer URL"
  value       = module.eks.oidc_issuer_url
}

output "cluster_security_group_id" {
  description = "EKS cluster primary security group ID"
  value       = module.eks.cluster_security_group_id
}

# Optional but useful for providers / debugging
output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

# -------- IAM / IRSA (keep if you're managing ALB IRSA outside EKS module) --------
output "cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane"
  value       = module.iam.cluster_role_arn
}

output "pod_execution_role_arn" {
  description = "Fargate pod execution role ARN"
  value       = module.iam.pod_execution_role_arn
}

# -------- Networking --------
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by EKS/Fargate"
  value       = module.vpc.private_subnet_ids
}
