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

# Security Group for an internet-facing NLB used by EKS/Fargate Services
resource "aws_security_group" "nlb" {
  name        = "${var.identifier}-nlb-sg"
  description = "Security group for NLB fronting EKS Fargate services"
  vpc_id      = var.vpc_id

  # Ingress: HTTP (80) from allowed CIDRs (use the variable)
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
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

  tags = merge(var.common_tags, {
    Name = "${var.identifier}-nlb-sg"
  })
}

# If you kept a separate rule for 5678, also use allowed_cidrs so TFLint is happy:
resource "aws_security_group_rule" "allow_client_to_pods_5678" {
  type              = "ingress"
  description       = "Allow TCP/5678 from allowed CIDRs to Fargate pod ENIs via NLB SG"
  from_port         = 5678
  to_port           = 5678
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidrs
  security_group_id = aws_security_group.nlb.id
}

# (OPTIONAL) If you previously added an ingress on this SG for 5678, you can remove it.
# NLB (IP targets) preserves client IP; the pod ENI needs the inbound rule, not the NLB SG.

# ✅ NEW: Allow client traffic to reach Fargate pods on TCP/5678 via the Cluster Security Group
# resource "aws_security_group_rule" "allow_client_to_pods_5678" {
#   type        = "ingress"
#   description = "TEMP: allow TCP/5678 from internet to Fargate pod ENIs via Cluster SG"
#   from_port   = 5678
#   to_port     = 5678
#   protocol    = "tcp"

#   # Because client IP is preserved by NLB (ip-target), allow 0.0.0.0/0 for test.
#   # (Tighten to your office IP(s) later.)
#   cidr_blocks = ["0.0.0.0/0"]

#   # 🔑 This is the EKS Cluster Security Group (applied to Fargate pod ENIs)
#   security_group_id = var.cluster_security_group_id
# }

# (Optional) Output the NLB SG id if you need it elsewhere
output "nlb_sg_id" {
  description = "NLB Security Group ID"
  value       = aws_security_group.nlb.id
}
