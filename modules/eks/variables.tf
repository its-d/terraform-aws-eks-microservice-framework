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
variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where the EKS cluster will be deployed."

}

variable "common_tags" {
  type        = map(string)
  description = "A map of common tags to apply to all resources."
  default     = {}
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "A list of subnet IDs for the EKS cluster."
}

variable "identifier" {
  type        = string
  description = "A unique identifier for the resources."
}

variable "cluster_role_arn" {
  type        = string
  description = "The ARN of the IAM role for the EKS cluster."
}

variable "pod_execution_role_arn" {
  type        = string
  description = "The ARN of the IAM role for EKS pod execution."

}

variable "public_access_cidrs" {
  type        = list(string)
  description = "Allowed CIDRs for public EKS API access (only used if public access is enabled)"
  default     = ["0.0.0.0/0"]
}
