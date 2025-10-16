#!/usr/bin/env bash
set -e

ENVIRONMENT=${1:-dev}

echo "🧩 Generating plan for environment: ${ENVIRONMENT}"
terraform plan -var-file="environments/${ENVIRONMENT}/terraform.tfvars" -out="plan-${ENVIRONMENT}.tfplan"
