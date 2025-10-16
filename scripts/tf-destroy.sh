#!/usr/bin/env bash
set -e

ENVIRONMENT=${1:-dev}

echo "💣 Destroying Terraform resources for environment: ${ENVIRONMENT}"
terraform destroy -var-file="environments/${ENVIRONMENT}/terraform.tfvars"
