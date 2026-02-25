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
# Pre-destroy cleanup: Helm uninstall, K8s resources, ALBs, ENIs.
# Run from repo root before terraform destroy.
# Idempotent; tolerates missing resources.

set -euo pipefail

echo "============================> Pre-destroy cleanup"

# --- K8s / Helm cleanup ---
CLUSTER="$(terraform output -raw cluster_name 2>/dev/null || true)"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

if [ -n "$CLUSTER" ]; then
  aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1 || true
  if kubectl --request-timeout=5s get ns >/dev/null 2>&1; then
    echo "  → Uninstalling Helm releases..."
    helm -n monitoring uninstall grafana --no-hooks --timeout 20s 2>/dev/null || true
    helm -n kube-system uninstall aws-load-balancer-controller --no-hooks --timeout 20s 2>/dev/null || true
    echo "  → Deleting monitoring namespace resources..."
    kubectl -n monitoring delete ingress,svc,deploy,statefulset,job,cronjob,cm,secret --all --ignore-not-found --wait=false 2>/dev/null || true
    kubectl -n monitoring delete pod --all --force --grace-period=0 --ignore-not-found 2>/dev/null || true
    kubectl delete namespace monitoring --ignore-not-found --wait=false 2>/dev/null || true
    if kubectl get ns monitoring -o json 2>/dev/null | grep -q finalizers; then
      kubectl get ns monitoring -o json | jq 'del(.spec.finalizers)' 2>/dev/null | kubectl replace --raw "/api/v1/namespaces/monitoring/finalize" -f - 2>/dev/null || true
    fi
  else
    echo "  → EKS API not reachable; skipping K8s cleanup."
  fi
else
  echo "  → No cluster_name output; skipping K8s cleanup."
fi

# --- AWS network cleanup ---
REGION="${REGION:-$(terraform output -raw region 2>/dev/null || true)}"
[ -z "$REGION" ] && REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
VPC_ID="$(terraform output -raw vpc_id 2>/dev/null || true)"
[ -z "$VPC_ID" ] && VPC_ID="$(cat .last_vpc_id 2>/dev/null || true)"
[ -n "$VPC_ID" ] && printf "%s\n" "$VPC_ID" > .last_vpc_id 2>/dev/null || true

if [ -n "$VPC_ID" ] && [[ "$VPC_ID" == vpc-* ]]; then
  echo "  → Deleting VPC endpoints in VPC $VPC_ID..."
  ep_ids=$(aws ec2 describe-vpc-endpoints --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC_ID" \
      --query 'VpcEndpoints[].VpcEndpointId' --output text 2>/dev/null || true)
  if [ -n "$ep_ids" ]; then
    aws ec2 delete-vpc-endpoints --region "$REGION" --vpc-endpoint-ids $ep_ids 2>/dev/null || true
    echo "  → Waiting 15s for endpoint ENIs to release..."
    sleep 15
  fi

  echo "  → Deleting load balancers in VPC $VPC_ID..."
  lbs=$(aws elbv2 describe-load-balancers --region "$REGION" \
    --query "LoadBalancers[?VpcId==\`$VPC_ID\`].LoadBalancerArn" --output text 2>/dev/null || true)
  if [ -n "$lbs" ]; then
    echo "$lbs" | tr '\t' '\n' | while read -r arn; do
      [ -n "$arn" ] && aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$arn" 2>/dev/null || true
    done
    echo "  → Waiting 30s for LB ENIs to release..."
    sleep 30
  fi

  echo "  → Cleaning ENIs in VPC $VPC_ID (with retries)..."
  for _ in 1 2 3 4 5; do
    enis=$(aws ec2 describe-network-interfaces --region "$REGION" \
        --filters Name=vpc-id,Values="$VPC_ID" \
        --query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Att:Attachment.AttachmentId}' \
        --output text 2>/dev/null || true)
    [ -z "$enis" ] && break
    echo "$enis" | while read -r line; do
      set -- $line
      ENI="${1:-}"
      ATT="${2:-}"
      [ -z "$ENI" ] && continue
      if [ -n "$ATT" ] && [ "$ATT" != "None" ]; then
        aws ec2 detach-network-interface --region "$REGION" --attachment-id "$ATT" --force 2>/dev/null || true
      fi
      aws ec2 delete-network-interface --region "$REGION" --network-interface-id "$ENI" 2>/dev/null || true
    done
    sleep 10
  done
else
  echo "  → No VPC ID found; skipping AWS network cleanup."
fi

echo "============================> Pre-destroy cleanup complete"
