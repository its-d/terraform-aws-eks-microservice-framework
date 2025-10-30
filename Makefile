# ==============================
# Makefile (root-driven Terraform)
# ==============================
.ONESHELL:
SHELL := /bin/bash

ENV    ?= dev
TFVARS ?= env/$(ENV)/terraform.tfvars
BACKEND ?= env/$(ENV)/backend.hcl
TF := terraform

# Stops command (plan/apply/destroy) if tfvars/backend files are missing
_guard_tfvars:
	@{ \
	  set -euo pipefail; \
	  if [ ! -f "$(TFVARS)" ]; then \
	    echo "Missing $(TFVARS). Create it or set ENV=<env>"; \
	    exit 1; \
	  fi; \
	}

# Stops init if backend file is missing
_guard_backend:
	@{ \
	  set -euo pipefail; \
	  if [ ! -f "$(BACKEND)" ]; then \
	    echo "Missing $(BACKEND). Create it (S3/Dynamo backend config) or set ENV=<env>"; \
	    exit 1; \
	  fi; \
	}

# Updates destroy process to forcibly clean up K8s/Helm resources first
_force_k8s_purge:
	@{ \
	  echo "============================> Forcing local K8s cleanup (Grafana ns/etc)"; \
	  set -euo pipefail; \
	  CLUSTER="$$(terraform output -raw cluster_name 2>/dev/null || true)"; \
	  REGION="$${AWS_REGION:-$${AWS_DEFAULT_REGION:-us-east-1}}"; \
	  if [ -z "$$CLUSTER" ]; then \
	    echo "↪ No cluster_name output; skipping kube cleanup."; \
	    exit 0; \
	  fi; \
	  aws eks update-kubeconfig --name "$$CLUSTER" --region "$$REGION" >/dev/null 2>&1 || true; \
	  if ! kubectl --request-timeout=5s get ns >/dev/null 2>&1; then \
	    echo "↪ API not reachable; skipping kube cleanup."; \
	    exit 0; \
	  fi; \
	  helm -n monitoring uninstall grafana --no-hooks --timeout 20s >/dev/null 2>&1 || true; \
	  helm -n kube-system uninstall aws-load-balancer-controller --no-hooks --timeout 20s >/dev/null 2>&1 || true; \
	  kubectl -n monitoring delete ingress,svc,deploy,statefulset,job,cronjob,cm,secret --all --ignore-not-found --wait=false >/dev/null 2>&1 || true; \
	  kubectl -n monitoring delete pod --all --force --grace-period=0 --ignore-not-found >/dev/null 2>&1 || true; \
	  kubectl delete namespace monitoring --ignore-not-found --wait=false >/dev/null 2>&1 || true; \
	  if kubectl get ns monitoring -o json >/dev/null 2>&1; then \
	    kubectl get ns monitoring -o json | jq 'del(.spec.finalizers)' | kubectl replace --raw "/api/v1/namespaces/monitoring/finalize" -f - >/dev/null 2>&1 || true; \
	  fi; \
	  echo "============================> K8s cleanup kicked off (non-blocking). Proceeding to AWS purge."; \
	}

# Removes K8s/Helm resources from Terraform state to avoid errors on destroy
_state_rm_k8s:
	@{ \
	  echo "============================> Removing K8s/Helm resources from Terraform state"; \
	  $(TF) state rm module.grafana.helm_release.grafana >/dev/null 2>&1 || true; \
	  $(TF) state rm module.grafana.kubernetes_namespace.monitoring >/dev/null 2>&1 || true; \
	  $(TF) state rm helm_release.aws_load_balancer_controller >/dev/null 2>&1 || true; \
	  $(TF) state rm kubernetes_config_map.aws_logging >/dev/null 2>&1 || true; \
	  $(TF) state list 2>/dev/null | grep -E '(^|\.)(helm_release|kubernetes_)' | xargs -I{} $(TF) state rm {} >/dev/null 2>&1 || true; \
	}

# Cleans up leftover AWS network resources (ALBs/ENIs) before destroy
_aws_net_purge:
	@{ \
	  echo "============================> Pre-cleaning ALBs & ENIs in this env"; \
	  set -euo pipefail; \
	  REGION="$$(terraform output -raw region 2>/dev/null || true)"; \
	  VPC_ID="$$(terraform output -raw vpc_id 2>/dev/null || true)"; \
	  [ -z "$$REGION" ] && REGION="$${AWS_REGION:-$${AWS_DEFAULT_REGION:-us-east-1}}"; \
	  echo "  → region=$$REGION vpc=$$VPC_ID"; \
	  aws elbv2 describe-load-balancers --region "$$REGION" \
	    --query 'LoadBalancers[?VpcId==`'$$VPC_ID'`].LoadBalancerArn' --output text 2>/dev/null | \
	    xargs -r -n1 aws elbv2 delete-load-balancer --region "$$REGION" --load-balancer-arn >/dev/null 2>&1 || true; \
	  for eni in $$(aws ec2 describe-network-interfaces --region "$$REGION" \
	      --filters Name=vpc-id,Values=$$VPC_ID \
	      --query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Att:Attachment.AttachmentId}' \
	      --output text 2>/dev/null); do \
	    set -- $$eni; \
	    ENI="$${1:-}"; \
	    ATT="$${2:-}"; \
	    [ -z "$$ENI" ] && continue; \
	    if [ -n "$$ATT" ] && [ "$$ATT" != "None" ]; then \
	      aws ec2 detach-network-interface --region "$$REGION" --attachment-id "$$ATT" >/dev/null 2>&1 || true; \
	    fi; \
	    aws ec2 delete-network-interface --region "$$REGION" --network-interface-id "$$ENI" >/dev/null 2>&1 || true; \
	  done; \
	}

# Currently there's an underlying dependency bug with VPC deletion in TF; this removes it from state to allow additional deletion step after destroy
_state_rm_vpc:
	@echo "============================> Removing VPC from Terraform state (and caching VPC ID)"
	@set -eu; \
	REGION="$${AWS_REGION:-$${AWS_DEFAULT_REGION:-us-east-1}}"; \
	IDENTIFIER="$$(TF_IN_AUTOMATION=1 $(TF) output -raw identifier 2>/dev/null || echo "main")"; \
	CLUSTER_NAME="$${IDENTIFIER}-eks-cluster"; \
	VPC_ID="$$(TF_IN_AUTOMATION=1 $(TF) output -raw vpc_id 2>/dev/null || true)"; \
	if [ -z "$$VPC_ID" ] || ! echo "$$VPC_ID" | grep -q '^vpc-'; then \
	  VPC_ID="$$(aws eks describe-cluster --region $$REGION --name $$CLUSTER_NAME \
	    --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null || true)"; \
	fi; \
	if echo "$$VPC_ID" | grep -q '^vpc-'; then \
	  printf "%s\n" "$$VPC_ID" > .last_vpc_id; \
	  echo "  → cached VPC ID: $$VPC_ID"; \
	else \
	  echo "  → no VPC ID found to cache (that’s okay)"; \
	fi; \
	-@$(TF) state rm 'module.vpc.module.vpc.aws_vpc.this[0]' >/dev/null 2>&1 || true

# Force deletes the VPC after destroy by attempting deletion multiple times (to allow for dependency cleanup)
_force_delete_vpc:
	@echo "============================> Forcibly deleting VPC from AWS (if still exists)" \
	@set -euo pipefail; \
	VPC_ID="$$(cat .last_vpc_id 2>/dev/null || true)"; \
	[ -z "$$VPC_ID" ] && { echo "↪ No cached VPC ID — skipping."; exit 0; }; \
	REGION="$${AWS_REGION:-$${AWS_DEFAULT_REGION:-us-east-1}}"; \
	# If VPC doesn't exist anymore, exit immediately
	if ! aws ec2 describe-vpcs --vpc-ids "$$VPC_ID" --region "$$REGION" >/dev/null 2>&1; then \
	  echo "============================>  VPC $$VPC_ID already deleted or not found."; \
	  rm -f .last_vpc_id >/dev/null 2>&1 || true; \
	  exit 0; \
	fi; \
	# Attempt up to 5 times (with small delay)
	for i in $$(seq 1 5); do \
	  if aws ec2 delete-vpc --region "$$REGION" --vpc-id "$$VPC_ID" >/dev/null 2>&1; then \
	    rm -f .last_vpc_id >/dev/null 2>&1 || true; \
	    echo "============================> VPC $$VPC_ID deleted"; \
	    exit 0; \
	  fi; \
	  sleep 3; \
	done; \
	echo "============================>  Skipped VPC $$VPC_ID — already removed or pending AWS cleanup."

# Confirms IP to use for EKS API access and saves to .make_env_public_access
_confirm_ip:
	@IP="$$(curl -s https://checkip.amazonaws.com)"; \
	TFVARS_IP="$$(grep -E 'public_access_cidrs' $(TFVARS) 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/32' | head -n1)"; \
	echo "============================> Detected current public IP: $$IP"; \
	if [ -n "$$TFVARS_IP" ]; then \
	  echo "============================> IP configured in $(TFVARS): $$TFVARS_IP"; \
	else \
	  echo "============================>  No public_access_cidrs found in $(TFVARS)"; \
	fi; \
	read -r -p "Use the IP from $(TFVARS) (y/N)? " USE_TFVARS; \
	case "$$USE_TFVARS" in \
	  [yY]) CIDR="$$TFVARS_IP";; \
	  *) read -r -p "Enter IP/CIDR to use (detected $$IP/32): " CIDR; \
	     [ -z "$$CIDR" ] && CIDR="$$IP/32";; \
	esac; \
	printf "export TF_VAR_public_access_cidrs='[\"%s\"]'\n" "$$CIDR" > .make_env_public_access; \
	echo "============================> Will allow $$CIDR (saved to .make_env_public_access)"

# Initializes Terraform with backend and all modules found in modules/ (Not including .* dirs)
init: _guard_backend
	@echo "🚀 Initializing Terraform (root) with backend $(BACKEND)"
	@$(TF) init -upgrade -reconfigure -backend-config=$(BACKEND)
	@echo "============================> Initializing all modules..."
	@for dir in $$(find modules -mindepth 1 -maxdepth 1 -type d ! -name ".*"); do \
		echo "→ Initializing $$dir"; \
		cd $$dir && $(TF) init -upgrade >/dev/null && cd - >/dev/null; \
	done
	@echo "============================> All Terraform modules initialized"

# Terraform plan using env tfvars and outputs to plan file
plan: _guard_tfvars
	@echo "============================> Planning for $(ENV)"
	$(MAKE) _confirm_ip
	@. ./.make_env_public_access; \
	$(TF) plan -var-file=$(TFVARS) -out=plan-$(ENV).tfplan

# Applies previously generated plan file
apply:
	@echo "============================> Applying plan for $(ENV)"
	$(TF) apply "plan-$(ENV).tfplan"

# Destroy resources for the selected environment including above pre-cleanup steps
destroy: _guard_tfvars
	@echo "============================> Destroying $(ENV)"
	$(MAKE) -s _aws_net_purge
	$(MAKE) -s _force_k8s_purge
	$(MAKE) -s _state_rm_k8s
	$(MAKE) -s _state_rm_vpc
	$(TF) destroy -var-file=$(TFVARS) -refresh=true -lock-timeout=5m
	$(MAKE) -s _force_delete_vpc

# Validates Terraform configuration syntax at root
validate:
	@echo "============================> Validating"
	$(TF) validate

# ==============================
# Quality & Docs
# ==============================

# Formats your Terraform files
fmt:
	@echo "============================> Formatting"
	$(TF) fmt -recursive

# Runs pre-commit hooks against all files
lint:
	@echo "============================> Running pre-commit hooks"
	pre-commit run --all-files

# Generates terraform-docs for all modules in modules/
docs:
	@echo "============================> Generating module documentation"
	@for d in modules/*; do \
	  if [ -d "$$d" ]; then \
	    echo "==> $$d"; \
	    terraform-docs markdown table $$d > $$d/README.md; \
	  fi; \
	done

# ==============================
# Utility
# ==============================

# Cleans up local Terraform files
clean:
	@echo "============================> Cleaning"
	rm -rf .terraform .terraform.lock.hcl plan-*.tfplan

# Displays help information
help:
	@echo "Available targets:"
	@echo ""
	@echo "Core:"
	@echo "  init        - Initialize Terraform backend/config for ENV using $(BACKEND)"
	@echo "  plan        - Generate Terraform plan using env tfvars -> plan-$(ENV).tfplan"
	@echo "  apply       - Apply Terraform changes using plan-$(ENV).tfplan"
	@echo "  destroy     - Destroy resources for the selected environment"
	@echo ""
	@echo "Utility:"
	@echo "  validate    - Validate Terraform configuration syntax"
	@echo "  fmt         - Format all Terraform files"
	@echo "  lint        - Run pre-commit checks"
	@echo "  docs        - Generate terraform-docs for all modules"
	@echo "  clean       - Remove local Terraform caches and plan files"
	@echo ""
	@echo "Usage: make <target> [ENV=dev|test|prod] or export ENV=dev"

.PHONY: init plan apply destroy validate fmt lint docs clean help
.DEFAULT_GOAL := help
