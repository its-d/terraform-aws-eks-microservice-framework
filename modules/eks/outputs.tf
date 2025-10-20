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
  value       = aws_eks_cluster.eks_cluster.name
  description = "value of the EKS cluster name"
}

output "oidc_issuer_url" {
  value       = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
  description = "OIDC issuer URL for the EKS cluster"
}

output "cluster_security_group_id" {
  description = "The EKS Cluster Security Group ID used by Fargate pod ENIs"
  value       = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
}
