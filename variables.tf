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
variable "region" {
  type        = string
  description = "AWS region (e.g., us-east-1)."
}

variable "environment" {
  type        = string
  description = "Environment name (e.g., dev, staging, prod)."
  default     = "dev"
}

variable "owner" {
  type        = string
  description = "Owner tag for resources."
  default     = ""
}

variable "identifier" {
  type        = string
  description = "Short prefix for resource names (e.g., myapp, sample)."
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the public EKS API. Default allows all (IAM is the control)."
  default     = ["0.0.0.0/0"]
}

variable "grafana_admin_user_arn" {
  type        = string
  description = "ARN of the Secrets Manager secret storing the Grafana admin username. Created by 'make plan' prompt if missing."
  default     = ""
}

variable "grafana_admin_pwd_arn" {
  type        = string
  description = "ARN of the Secrets Manager secret storing the Grafana admin password. Created by 'make plan' prompt if missing."
  default     = ""
}

variable "enable_https" {
  type        = bool
  description = "Enable HTTPS for Grafana ALB. Requires certificate_arn."
  default     = false
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for Grafana HTTPS. Required when enable_https is true."
  default     = ""
}
