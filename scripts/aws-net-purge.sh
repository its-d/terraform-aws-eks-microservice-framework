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
# Cleans up leftover AWS network resources (ALBs/ENIs) before destroy.
# Run from repo root.

set -euo pipefail

echo "============================> Pre-cleaning ALBs & ENIs in this env"
REGION="$(terraform output -raw region 2>/dev/null || true)"
VPC_ID="$(terraform output -raw vpc_id 2>/dev/null || true)"
[ -z "$REGION" ] && REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
echo "  → region=$REGION vpc=$VPC_ID"

# Portable: avoid xargs -r (GNU-only); use loop for empty-input safety
lbs=$(aws elbv2 describe-load-balancers --region "$REGION" \
  --query "LoadBalancers[?VpcId==\`$VPC_ID\`].LoadBalancerArn" --output text 2>/dev/null || true)
if [ -n "$lbs" ]; then
  echo "$lbs" | tr '\t' '\n' | while read -r arn; do
    [ -n "$arn" ] && aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$arn" >/dev/null 2>&1 || true
  done
fi

for eni in $(aws ec2 describe-network-interfaces --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" \
    --query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Att:Attachment.AttachmentId}' \
    --output text 2>/dev/null); do
  set -- $eni
  ENI="${1:-}"
  ATT="${2:-}"
  [ -z "$ENI" ] && continue
  if [ -n "$ATT" ] && [ "$ATT" != "None" ]; then
    aws ec2 detach-network-interface --region "$REGION" --attachment-id "$ATT" >/dev/null 2>&1 || true
  fi
  aws ec2 delete-network-interface --region "$REGION" --network-interface-id "$ENI" >/dev/null 2>&1 || true
done
