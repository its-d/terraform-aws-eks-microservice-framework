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
# Removes VPC from Terraform state and caches VPC ID to .last_vpc_id.
# Workaround for underlying dependency bug with VPC deletion in TF.
# Run from repo root.

set -eu

TF="${TF:-terraform}"
echo "============================> Removing VPC from Terraform state (and caching VPC ID)"

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
IDENTIFIER="$(TF_IN_AUTOMATION=1 $TF output -raw identifier 2>/dev/null || echo "main")"
CLUSTER_NAME="${IDENTIFIER}-eks-cluster"
VPC_ID="$(TF_IN_AUTOMATION=1 $TF output -raw vpc_id 2>/dev/null || true)"

if [ -z "$VPC_ID" ] || ! echo "$VPC_ID" | grep -q '^vpc-'; then
  VPC_ID="$(aws eks describe-cluster --region "$REGION" --name "$CLUSTER_NAME" \
    --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null || true)"
fi

if echo "$VPC_ID" | grep -q '^vpc-'; then
  printf "%s\n" "$VPC_ID" > .last_vpc_id
  echo "  → cached VPC ID: $VPC_ID"
else
  echo "  → no VPC ID found to cache (that's okay)"
fi

$TF state rm 'module.vpc.module.vpc.aws_vpc.this[0]' >/dev/null 2>&1 || true
