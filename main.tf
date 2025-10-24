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


# -------------------------
# Terraform Settings
# -------------------------
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
  }

  backend "s3" {}
}

# -------------------------
# Data Source helpers for EKS cluster access
# -------------------------
data "aws_eks_cluster" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# -------------------------
# Providers
# -------------------------
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "aws" {
  region = var.region
}

# -------------------------
# Setting Resource Tag Variables
# -------------------------
locals {
  common_tags = {
    Identifier  = var.identifier
    Environment = var.environment
    Owner       = var.owner
  }
}

# -------------------------
# Module responsible for EKS configuration
# and Fargate Profile setup
# -------------------------
module "eks" {
  source                  = "./modules/eks/"
  identifier              = var.identifier
  region                  = var.region
  common_tags             = local.common_tags
  private_subnet_ids      = module.vpc.private_subnet_ids
  cluster_role_arn        = module.iam.cluster_role_arn
  pod_execution_role_arn  = module.iam.pod_execution_role_arn
  endpoint_private_access = var.endpoint_private_access
  endpoint_public_access  = var.endpoint_public_access
  public_access_cidrs     = var.public_access_cidrs
  depends_on              = [module.vpc]
}

# -------------------------
# Module responsible for Cluster
# and Pod execution role
# -------------------------
module "iam" {
  source      = "./modules/iam"
  common_tags = local.common_tags
}

# -------------------------
# Module responsible for IAM Roles
# for Service Accounts (IRSA)
# -------------------------
module "iam_irsa" {
  source          = "./modules/iam_irsa"
  common_tags     = local.common_tags
  oidc_issuer_url = module.eks.oidc_issuer_url
  depends_on      = [module.eks]
}

# -------------------------
# Module responsible for Security Groups
# -------------------------
module "security" {
  source                    = "./modules/security"
  vpc_id                    = module.vpc.vpc_id
  cluster_security_group_id = module.eks.cluster_security_group_id
  common_tags               = local.common_tags
  depends_on                = [module.eks]
}

# -------------------------
# Module responsible for Storage (EFS)
# -------------------------
module "storage" {
  source                = "./modules/storage"
  identifier            = var.identifier
  private_subnet_ids    = module.vpc.private_subnet_ids
  efs_security_group_id = module.security.efs_sg_id
  common_tags           = local.common_tags
}

# -------------------------
# Module responsible for Grafana deployment
# -------------------------
module "grafana" {
  source                 = "./modules/grafana"
  identifier             = var.identifier
  region                 = var.region
  efs_file_system_id     = module.storage.efs_file_system_id
  efs_access_point_id    = module.storage.efs_access_point_id
  grafana_admin_password = var.grafana_admin_password
  grafana_admin_user     = var.grafana_admin_user
  depends_on = [
    module.eks,
    helm_release.aws_load_balancer_controller
  ]
}

# -------------------------
# Module responsible for VPC creation
# -------------------------
module "vpc" {
  source      = "./modules/vpc"
  environment = var.environment
  identifier  = var.identifier
  common_tags = local.common_tags
}
