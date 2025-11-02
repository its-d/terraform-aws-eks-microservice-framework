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
  description = "The AWS region where the resources are deployed."

}

variable "self_signed_certificate_arn" {
  description = "ARN of the secret storing the TLS certificate for the ALB"
  type        = string

}

variable "enable_https" {
  type    = bool
  default = false
}

variable "grafana_user_arn" {
  description = "ARN of the secret storing the Grafana admin username"
  type        = string
}

variable "grafana_pwd_arn" {
  description = "ARN of the secret storing the Grafana admin password"
  type        = string
}
