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
# Force deletes the VPC from AWS after destroy (reads .last_vpc_id).
# Attempts deletion multiple times to allow for dependency cleanup.
# Run from repo root.

set -euo pipefail

echo "============================> Forcibly deleting VPC from AWS (if still exists)"
VPC_ID="$(cat .last_vpc_id 2>/dev/null || true)"
[ -z "$VPC_ID" ] && { echo "↪ No cached VPC ID — skipping."; exit 0; }

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

if ! aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$REGION" >/dev/null 2>&1; then
  echo "============================>  VPC $VPC_ID already deleted or not found."
  rm -f .last_vpc_id >/dev/null 2>&1 || true
  exit 0
fi

for i in $(seq 1 5); do
  if aws ec2 delete-vpc --region "$REGION" --vpc-id "$VPC_ID" >/dev/null 2>&1; then
    rm -f .last_vpc_id >/dev/null 2>&1 || true
    echo "============================> VPC $VPC_ID deleted"
    exit 0
  fi
  sleep 3
done
echo "============================>  Skipped VPC $VPC_ID — already removed or pending AWS cleanup."
