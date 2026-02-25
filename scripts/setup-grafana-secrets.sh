#!/usr/bin/env bash
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
#
# Prompts for Grafana admin credentials, creates Secrets Manager secrets,
# and updates terraform.tfvars with the ARNs.
# Run from repo root. Requires AWS CLI and jq.

set -euo pipefail

TFVARS="${TFVARS:-terraform.tfvars}"
IDENTIFIER="${IDENTIFIER:-$(grep -E '^\s*identifier\s*=' "$TFVARS" 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/' || echo "main")}"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

echo "============================> Grafana credentials setup"
echo "  → Will create Secrets Manager secrets and update $TFVARS"
echo ""

read -r -p "Grafana admin username [admin]: " GRAFANA_USER
GRAFANA_USER="${GRAFANA_USER:-admin}"

read -r -s -p "Grafana admin password: " GRAFANA_PWD
echo ""
if [ -z "$GRAFANA_PWD" ]; then
  echo "ERROR: Password cannot be empty."
  exit 1
fi

SECRET_NAME_USER="${IDENTIFIER}-grafana-admin-user"
SECRET_NAME_PWD="${IDENTIFIER}-grafana-admin-pwd"

echo "  → Creating secret: $SECRET_NAME_USER"
USER_ARN=$(aws secretsmanager create-secret \
  --name "$SECRET_NAME_USER" \
  --secret-string "$GRAFANA_USER" \
  --region "$REGION" \
  --query 'ARN' --output text 2>/dev/null || \
  aws secretsmanager put-secret-value \
  --secret-id "$SECRET_NAME_USER" \
  --secret-string "$GRAFANA_USER" \
  --region "$REGION" \
  --query 'ARN' --output text 2>/dev/null || true)

if [ -z "$USER_ARN" ]; then
  echo "ERROR: Failed to create/update user secret."
  exit 1
fi

echo "  → Creating secret: $SECRET_NAME_PWD"
PWD_ARN=$(aws secretsmanager create-secret \
  --name "$SECRET_NAME_PWD" \
  --secret-string "$GRAFANA_PWD" \
  --region "$REGION" \
  --query 'ARN' --output text 2>/dev/null || \
  aws secretsmanager put-secret-value \
  --secret-id "$SECRET_NAME_PWD" \
  --secret-string "$GRAFANA_PWD" \
  --region "$REGION" \
  --query 'ARN' --output text 2>/dev/null || true)

if [ -z "$PWD_ARN" ]; then
  echo "ERROR: Failed to create/update password secret."
  exit 1
fi

# Update or append to tfvars (sed -i '' for macOS, -i for Linux)
_sed_inplace() {
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "$1" "$2"
  else
    sed -i "$1" "$2"
  fi
}

if [ -f "$TFVARS" ]; then
  if grep -q "grafana_admin_user_arn" "$TFVARS" 2>/dev/null; then
    _sed_inplace "s|grafana_admin_user_arn.*=.*|grafana_admin_user_arn      = \"$USER_ARN\"|" "$TFVARS"
    _sed_inplace "s|grafana_admin_pwd_arn.*=.*|grafana_admin_pwd_arn       = \"$PWD_ARN\"|" "$TFVARS"
  else
    echo "" >> "$TFVARS"
    echo "grafana_admin_user_arn      = \"$USER_ARN\"" >> "$TFVARS"
    echo "grafana_admin_pwd_arn       = \"$PWD_ARN\"" >> "$TFVARS"
  fi
else
  echo "grafana_admin_user_arn      = \"$USER_ARN\"" > "$TFVARS"
  echo "grafana_admin_pwd_arn       = \"$PWD_ARN\"" >> "$TFVARS"
fi

echo ""
echo "============================> Grafana secrets created and $TFVARS updated"
