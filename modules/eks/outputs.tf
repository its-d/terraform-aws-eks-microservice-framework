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

output "cluster_name" {
  value       = module.eks.cluster_name
  description = "value of the EKS cluster name"
}

output "oidc_issuer_url" {
  value       = module.eks.cluster_oidc_issuer_url
  description = "OIDC issuer URL for the EKS cluster"
}

output "cluster_security_group_id" {
  description = "The EKS Cluster Security Group ID used by Fargate pod ENIs"
  value       = module.eks.node_security_group_id
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate data required to access the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA integration"
  value       = module.eks.oidc_provider_arn
}

output "fargate_profile_arn" {
  description = "ARN of the created Fargate profile"
  value       = try(module.eks.fargate_profile_arn, null)
}
