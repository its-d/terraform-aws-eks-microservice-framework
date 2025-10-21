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

  backend "local" {
    path = "terraform.tfstate"
  }
}

# Ask AWS for live EKS connection details (no kubeconfig needed)
data "aws_eks_cluster" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# Kubernetes provider uses the EKS endpoint/CA/token directly
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# Helm provider reuses the same EKS connection
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


locals {
  common_tags = {
    Identifier  = var.identifier
    Environment = var.environment
    Owner       = var.owner
  }
}

module "app" {
  source = "./modules/app"
}

module "eks" {
  source      = "./modules/eks/"
  identifier  = var.identifier
  common_tags = local.common_tags

  # Networking
  private_subnet_ids = module.vpc.private_subnet_ids

  # 👇 Use the actual output names from modules/iam/outputs.tf
  cluster_role_arn       = module.iam.cluster_role_arn
  pod_execution_role_arn = module.iam.pod_execution_role_arn
}

module "iam" {
  source      = "./modules/iam"
  common_tags = local.common_tags
}

module "iam_irsa" {
  source          = "./modules/iam_irsa"
  common_tags     = local.common_tags
  oidc_issuer_url = module.eks.oidc_issuer_url
}

module "security" {
  source                    = "./modules/security"
  vpc_id                    = module.vpc.vpc_id
  cluster_security_group_id = module.eks.cluster_security_group_id
  common_tags               = local.common_tags
}

module "vpc" {
  source      = "./modules/vpc"
  environment = var.environment
  identifier  = var.identifier
  common_tags = local.common_tags
}
