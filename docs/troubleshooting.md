# 🩺 Troubleshooting

Common issues with steps to diagnose and resolve.

---

## Load Balancer Not Creating or Service Stuck in Pending

Symptoms
- Service remains in `Pending`.
- No NLB/ALB visible in AWS console.

Checks & Fixes
- Check controller logs:
```bash
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller
```
- Ensure the IRSA role policy includes ELB permissions (see modules/iam_irsa/policies).
- Confirm Service annotations such as:
  - `service.beta.kubernetes.io/aws-load-balancer-type: "nlb"`
  - correct port/targetPort values.
- Re-apply Terraform/Helm for controller if IAM policy was updated.

---

## AccessDenied on ELB APIs

Example:
```
AccessDenied: User is not authorized to perform: elasticloadbalancing:DescribeListenerAttributes
```

Fixes:
- Ensure the IAM role used by the controller has the correct managed/custom policy.
- If using IRSA, verify service account annotation matches the IAM role ARN and the trust policy.

---

## Pods Pending — No Nodes Available (Fargate profiles)

Cause:
- Namespace is not included in a Fargate profile; pods have no scheduling target.

Fix:
- Add namespace to Fargate profile in the EKS module, then terraform apply.
- Alternatively run workloads in a namespace covered by an existing Fargate profile.

---

## Grafana Related Issues

Symptoms
- Grafana Pod cannot start or crashes with mount errors.
- Grafana deployment starts but dashboards are not persisted after restart.

1. Grafana Data Persistence
   - If Grafana starts but dashboards disappear after pod restart, confirm the mount is writable and Grafana is writing to the mounted path (`/var/lib/grafana` or chart-specific path).

---

## Clean Destroy / VPC DependencyViolation

`make destroy` runs pre-cleanup (Helm uninstall, K8s resources, VPC endpoints, ALBs, ENIs; removes Helm/K8s from state), state-rm-vpc, terraform destroy, and force-delete-vpc. If destroy fails with `DependencyViolation: The vpc 'vpc-xxx' has dependencies`:

1. **Retry with cleanup** (pre-destroy now cleans VPC endpoints and retries ENI cleanup):
```bash
make destroy-retry
```

2. **Verify resources**:
```bash
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=vpc-xxx" --region us-east-1
aws ec2 describe-network-interfaces --filters Name=vpc-id,Values=vpc-xxx --region us-east-1
aws elbv2 describe-load-balancers --region us-east-1  # filter by VPC in console
```

3. **Last resort** (orphan VPC from state, force-delete from AWS):
```bash
bash scripts/state-rm-vpc.sh
terraform destroy -var-file=terraform.tfvars -refresh=false
bash scripts/force-delete-vpc.sh
```

---

## State Lock Issues

If using DynamoDB for state locking and you see a stale lock:
- Inspect the lock in DynamoDB console; remove if no concurrent process is running.
- Ensure IAM permissions for DynamoDB (PutItem/DeleteItem).

---

## kubeconfig / auth issues

Symptoms:
- aws eks update-kubeconfig fails, or kubectl commands return Unauthorized.

Fix:
- Ensure AWS CLI credentials used are allowed to call eks:DescribeCluster and sts:GetCallerIdentity.
- Confirm region and cluster name are correct.
- If using assumed roles, include --role-arn with update-kubeconfig or ensure your AWS profile is configured to assume the role.

---

## ALB Controller / Helm failures

Fixes:
- Verify Helm chart version and values; consult Helm release history:
```bash
helm -n kube-system list
helm -n kube-system status <release>
kubectl -n kube-system describe pod <pod>
kubectl -n kube-system logs <pod>
```
- Ensure chart resources are created in the correct namespace and RBAC is applied.

---

## Debugging Tips & Useful Commands

- View all pods:
```bash
kubectl get pods -A
```

- View events:
```bash
kubectl get events --sort-by=.lastTimestamp
```

- Describe service:
```bash
kubectl describe svc <service> -n <namespace>
```

- Check ENIs in AWS:
  - EC2 Console -> Network Interfaces, filter by description/tag

- Terraform debugging:
```bash
TF_LOG=DEBUG terraform apply
```

---

If you encounter an issue not covered here, collect the following and open an issue (or attach to your PR):
- terraform plan output
- terraform state list (if relevant)
- kubectl get pods -A and kubectl describe for problem resources
- logs from relevant pods (controller/application)
- relevant AWS console screenshots or IDs
