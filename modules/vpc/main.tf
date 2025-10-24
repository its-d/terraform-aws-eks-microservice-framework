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

/*
-------------------------
* Module: VPC
* Description: Creates a VPC with public and private subnets across two AZs.
* Variables required:
  - identifier
  - environment
  - common_tags
-------------------------
*/
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.4"

  name = "${var.identifier}-${var.environment}-vpc"
  cidr = "10.0.0.0/16"

  # Two AZs in us-east-1
  azs = ["us-east-1a", "us-east-1b"]

  # 2 public + 2 private subnets (any /24s are fine)
  public_subnets  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnets = ["10.0.100.0/24", "10.0.101.0/24"]

  # Basics you almost always want
  enable_dns_support      = true
  enable_dns_hostnames    = true
  map_public_ip_on_launch = true

  # NAT for private subnets (cost-friendly single NAT)
  enable_nat_gateway = true
  single_nat_gateway = true

  # Helpful tags on subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = var.common_tags
}
