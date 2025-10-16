#!/usr/bin/env bash
set -e

ENVIRONMENT=${1:-dev}

echo "🚀 Applying Terraform changes for environment: ${ENVIRONMENT}"
terraform apply "plan-${ENVIRONMENT}.tfplan"
