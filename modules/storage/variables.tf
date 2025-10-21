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

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "identifier" {
  description = "Identifier for naming resources"
  type        = string

}

variable "private_subnet_ids" {
  description = "List of private subnet IDs where EFS mount targets will be created"
  type        = list(string)
}

variable "efs_security_group_id" {
  description = "Security Group ID to associate with the EFS mount targets"
  type        = string
}
