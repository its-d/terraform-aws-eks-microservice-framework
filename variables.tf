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
  default     = "us-east-1"
  description = "AWS Region to be associated with the deployment."
}

variable "environment" {
  type        = string
  description = "The environment for the resources (e.g., dev, staging, prod)."
}

variable "owner" {
  type        = string
  description = "The owner of the resources."
}

variable "identifier" {
  type        = string
  description = "A unique identifier for the resources."
}
