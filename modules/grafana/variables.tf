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

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true

}

variable "identifier" {
  type        = string
  description = "A unique identifier for the resources."

}

variable "efs_file_system_id" {
  type        = string
  description = "The ID of the EFS file system to be used by Grafana for storage."

}

variable "efs_access_point_id" {
  type        = string
  description = "The ID of the EFS access point to be used by Grafana for storage."

}
