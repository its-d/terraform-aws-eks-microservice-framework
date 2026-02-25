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
# Forcibly cleans up K8s/Helm resources (Grafana, ALB controller, monitoring ns) before destroy.
# Run from repo root.

set -euo pipefail

echo "============================> Forcing local K8s cleanup (Grafana ns/etc)"
CLUSTER="$(terraform output -raw cluster_name 2>/dev/null || true)"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

if [ -z "$CLUSTER" ]; then
  echo "↪ No cluster_name output; skipping kube cleanup."
  exit 0
fi

aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" >/dev/null 2>&1 || true
if ! kubectl --request-timeout=5s get ns >/dev/null 2>&1; then
  echo "↪ API not reachable; skipping kube cleanup."
  exit 0
fi

helm -n monitoring uninstall grafana --no-hooks --timeout 20s >/dev/null 2>&1 || true
helm -n kube-system uninstall aws-load-balancer-controller --no-hooks --timeout 20s >/dev/null 2>&1 || true
kubectl -n monitoring delete ingress,svc,deploy,statefulset,job,cronjob,cm,secret --all --ignore-not-found --wait=false >/dev/null 2>&1 || true
kubectl -n monitoring delete pod --all --force --grace-period=0 --ignore-not-found >/dev/null 2>&1 || true
kubectl delete namespace monitoring --ignore-not-found --wait=false >/dev/null 2>&1 || true
if kubectl get ns monitoring -o json >/dev/null 2>&1; then
  kubectl get ns monitoring -o json | jq 'del(.spec.finalizers)' | kubectl replace --raw "/api/v1/namespaces/monitoring/finalize" -f - >/dev/null 2>&1 || true
fi
echo "============================> K8s cleanup kicked off (non-blocking). Proceeding to AWS purge."
