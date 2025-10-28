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
----------------------------
* Module: EKS
* Description: Creates an EKS cluster with Fargate profiles and configures CoreDNS to run on Fargate.
* Variables required:
  - identifier
  - public_access_cidrs
  - cluster_role_arn
  - vpc_id
  - private_subnet_ids
  - common_tags
----------------------------
*/
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.identifier}-eks-cluster"
  cluster_version = "1.33"

  cluster_endpoint_private_access          = true
  cluster_endpoint_public_access           = true
  cluster_endpoint_public_access_cidrs     = var.public_access_cidrs
  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = true
  iam_role_arn                             = var.cluster_role_arn

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  cluster_addons = {
    coredns = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"

      configuration_values = jsonencode({
        # force CoreDNS onto Fargate
        computeType = "Fargate"
        nodeSelector = {
          "eks.amazonaws.com/compute-type" = "fargate"
        }
        tolerations = [{
          key      = "eks.amazonaws.com/compute-type"
          operator = "Equal"
          value    = "fargate"
          effect   = "NoSchedule"
        }]
        resources = {
          limits   = { cpu = "0.25", memory = "256M" }
          requests = { cpu = "0.25", memory = "256M" }
        }
      })
    }
    kube-proxy = {}
    vpc-cni    = {}
  }

  fargate_profile_defaults = {
    pod_execution_role_arn = var.pod_execution_role_arn
    subnet_ids             = var.private_subnet_ids
  }

  fargate_profiles = {
    kube_system = {
      name = "kube-system"
      selectors = [
        # Default namespace pods
        { namespace = "default" },

        # Monitoring namespace pods
        { namespace = "monitoring" },

        # CoreDNS pods in kube-system
        {
          namespace = "kube-system"
          labels = {
            k8s-app = "kube-dns"
          }
        },

        # AWS Load Balancer Controller pods
        {
          namespace = "kube-system"
          labels = {
            "app.kubernetes.io/name" = "aws-load-balancer-controller"
          }
        }
      ]
    }
  }

  tags = var.common_tags

}
