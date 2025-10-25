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

## Grafana / EFS Related Issues

Symptoms
- Grafana Pod cannot start or crashes with mount errors.
- Grafana deployment starts but dashboards are not persisted after restart.
- EFS mount shows permission denied.

Checks & Fixes
1. Verify EFS Access Point & File System
   - Confirm Access Point exists and is correctly configured to use UID/GID expected by Grafana.

2. Check Security Groups and Mount Targets
   - Ensure EFS mount targets exist in the same subnets/AZs used by the cluster.
   - Security group for EFS must allow inbound TCP 2049 from the cluster ENIs/SGs.
   - Troubleshoot NFS connectivity from a pod (use a debug pod with nfs-utils if allowed).

3. Permissions & POSIX User Mapping
   - If using Access Points, ensure the posixUser is correctly set (Uid/Gid) for Grafana process.
   - Inspect pod logs for permission errors and adjust Access Point creation settings.

4. PVC / PV Binding
   - Check PersistentVolume and PersistentVolumeClaim:
```bash
kubectl get pv,pvc -n monitoring
kubectl describe pvc <pvc-name> -n monitoring
```
   - Ensure PV has the correct `volumeHandle` (EFS ID) and access point settings.

1. Grafana Data Persistence
   - If Grafana starts but dashboards disappear after pod restart, confirm the mount is writable and Grafana is writing to the mounted path (`/var/lib/grafana` or chart-specific path).

---

## Clean Destroy / Resource-in-use Errors (ENIs, Target Groups, EFS mounts)

Cause:
- K8s controllers or pods left AWS resources attached (ENIs, target groups, EFS mounts). Terraform cannot delete VPCs/subnets/security groups with attached resources.

Recommended Steps:
1. Delete Kubernetes resources:
```bash
kubectl delete -f k8s/service-hello-world.yaml
kubectl delete -f k8s/deployment-hello-world.yaml
# If Grafana is installed:
kubectl -n monitoring delete deploy grafana
helm -n monitoring uninstall grafana  # if installed via helm
```
2. Wait for pods and ENIs to be removed. Verify:

- Kubernetes:
```bash
kubectl get pods -A
```

- AWS:
  - EC2 Console -> Network Interfaces (Search for cluster name tags)
  - EFS Console -> Mount targets (ensure no active mounts - note: EFS won't list mounts the same way; verify Pods are gone)
  - ELB Console -> Target Groups -> Targets (ensure none remain healthy/attached)

3. If Terraform still errors, use:
```bash
terraform state list   # find stuck resource addresses
terraform state rm <address>  # remove resource from state (dangerous; last resort)
terraform destroy -auto-approve
```
Note: Use state rm only if you accept that Terraform will no longer track that resource.

---

## State Lock / DynamoDB Lock Issues

Symptoms:
- terraform init or apply fails due to a stale lock.

Fix:
- Use DynamoDB console to inspect lock record (table used for locking). Remove lock if you're certain no concurrent process is using it.
- Configure proper IAM permissions for the user/role that runs Terraform (DynamoDB: PutItem/DeleteItem).

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
