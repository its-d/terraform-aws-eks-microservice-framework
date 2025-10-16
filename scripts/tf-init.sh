#!/usr/bin/env bash
set -e

ENVIRONMENT=${1:-dev}

echo "🚀 Initializing Terraform for environment: ${ENVIRONMENT}"
terraform init -backend-config="environments/${ENVIRONMENT}/backend.tfvars"
