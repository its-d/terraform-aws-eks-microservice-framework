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
# I need an AWS Module for a VPC with public and private subnets, NAT Gateway, and Internet Gateway.

variable "environment" {
  type        = string
  description = "The environment for the resources (e.g., dev, staging, prod)."
}

variable "identifier" {
  type        = string
  description = "A unique identifier for the resources."
}

variable "common_tags" {
  type        = map(string)
  description = "A map of common tags to apply to all resources."
  default     = {}
}

variable "azs" {
  type        = list(string)
  description = "Availability zones for subnets. If empty, first two AZs from region are used."
  default     = []
}

variable "cidr" {
  type        = string
  description = "VPC CIDR block."
  default     = "10.0.0.0/16"
}
