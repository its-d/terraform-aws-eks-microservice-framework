# 🧯 Troubleshooting Guide

Common issues and their resolutions for the **terraform-aws-eks-microservice-framework**.

---

## 🚫 Load Balancer Not Creating

**Symptom:** Service stuck in `Pending` or NLB not visible in AWS Console.

**Fix:**
- Ensure `aws-load-balancer-controller` IAM role has full ELBv2 permissions.
- Confirm the `service.beta.kubernetes.io/aws-load-balancer-type` annotation is set to `"nlb"`.
- Check logs:
  ```bash
  kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller
  ```

---

## ❌ “AccessDenied” on ELB APIs

**Symptom:**
```
AccessDenied: User is not authorized to perform: elasticloadbalancing:DescribeListenerAttributes
```

**Fix:**
- Update IRSA policy (`modules/iam_irsa/policies/aws_load_balancer_controller_iam_policy.json`).
- Reapply Terraform:
  ```bash
  make apply ENV=dev
  ```

---

## 🕳️ Pods Pending (No Nodes Available)

**Cause:** Namespace lacks Fargate profile coverage.

**Fix:**
- Update your EKS module to include that namespace in the Fargate profile.
- Re-run `terraform apply`.

---

## 🌐 Curl Returns Empty Reply

**Symptom:** NLB resolves but returns no data.

**Fix:**
- Ensure correct **target port (5678)** and security group ingress rule are set.
- Validate the endpoint:
  ```bash
  kubectl get endpoints hello-world
  ```

---

## 🧹 Clean Destroy

To safely remove all resources:
```bash
make destroy ENV=dev
```

If errors occur due to dependency order:
```bash
terraform state rm <resource_id>
terraform destroy -auto-approve
```

---

## 🪪 IAM & IRSA Validation

Check the IRSA annotation on the service account:
```bash
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml
```

Ensure the ARN matches your IAM role and trust policy.

---

## 🧰 Debugging Tips

- View all pods: `kubectl get pods -A`
- Get events: `kubectl get events --sort-by=.lastTimestamp`
- Describe resource: `kubectl describe svc <service>`
- Check AWS console for NLB target health under “Target Groups”.

---
