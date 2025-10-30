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
------------------------
* Resource: ALB Security Group
* Description: Security group for ALB fronting EKS Fargate services
* Variables:
  - vpc_id
  - allowed_cidrs
  - common_tags
------------------------
*/
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for ALB fronting EKS Fargate services"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs

  }

  # Egress: allow all
  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.common_tags
}

/*
------------------------
* Resource: Cluster Security Group Rule for ALB
* Description: Allows ALB security group to access EKS cluster security group on port 3000
* Variables:
  - cluster_security_group_id
------------------------
*/
resource "aws_security_group_rule" "csg_rule" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = var.cluster_security_group_id
  source_security_group_id = aws_security_group.alb_sg.id
  description              = "Allows ALB to Pods on 3000/tcp"
}

/*
------------------------
* Resource: Grafana Admin and Password Secrets
* Description: Secret for Grafana admin user/password
* Variables:
  - grafana_user_arn
  - grafana_pwd_arn
------------------------
*/
data "aws_secretsmanager_secret_version" "sm_user_version" {
  secret_id = var.grafana_user_arn
}

data "aws_secretsmanager_secret_version" "sm_pwd_version" {
  secret_id = var.grafana_pwd_arn
}

locals {
  grafana_admin_user = sensitive(data.aws_secretsmanager_secret_version.sm_user_version.secret_string)
  grafana_admin_pwd  = sensitive(data.aws_secretsmanager_secret_version.sm_pwd_version.secret_string)
}
