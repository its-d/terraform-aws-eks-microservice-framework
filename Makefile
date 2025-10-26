# ==============================
# Makefile (root-driven Terraform)
# ==============================

ENV    ?= dev
TFVARS ?= env/$(ENV)/terraform.tfvars
BACKEND ?= env/$(ENV)/backend.hcl
TF := terraform

GREEN  := \033[0;32m
YELLOW := \033[1;33m
RESET  := \033[0m

# Stops command (plan/apply/destroy) if tfvars/backend files are missing
_guard_tfvars:
	@if [ ! -f "$(TFVARS)" ]; then \
		echo "$(YELLOW)Missing $(TFVARS). Create it or set ENV=<env>$(RESET)"; \
		exit 1; \
	fi

# Stops init if backend file is missing
_guard_backend:
	@if [ ! -f "$(BACKEND)" ]; then \
		echo "$(YELLOW)Missing $(BACKEND). Create it (S3/Dynamo backend config) or set ENV=<env>$(RESET)"; \
		exit 1; \
	fi

# Updates destroy process to forcibly clean up K8s/Helm resources first
_force_k8s_purge:
	@echo "$(YELLOW)🧨 Forcing local K8s cleanup (Grafana ns/PV/etc)$(RESET)"
	-@aws eks update-kubeconfig --name "$$(terraform output -raw cluster_name 2>/dev/null)" \
		--region "$${AWS_REGION:-$${AWS_DEFAULT_REGION:-us-east-1}}" >/dev/null 2>&1 || true

	# Helm releases (ignore if already gone)
	-@helm -n monitoring uninstall grafana --wait=false >/dev/null 2>&1 || true
	-@helm -n kube-system uninstall aws-load-balancer-controller --wait=false >/dev/null 2>&1 || true

	# Ingress / svc / deploy / PVCs (don’t wait)
	-@kubectl -n monitoring delete ingress --all --ignore-not-found --wait=false >/dev/null 2>&1 || true
	-@kubectl -n monitoring delete svc --all --ignore-not-found --wait=false >/dev/null 2>&1 || true
	-@kubectl -n monitoring delete deploy --all --ignore-not-found --wait=false >/dev/null 2>&1 || true
	-@kubectl -n monitoring delete pvc --all --ignore-not-found --wait=false >/dev/null 2>&1 || true
	-@for pvc in $$(kubectl -n monitoring get pvc -o name 2>/dev/null); do \
		kubectl -n monitoring patch $$pvc --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true; \
	done

	# PVs (only the grafana PV by name pattern)
	-@kubectl get pv -o name 2>/dev/null | grep -E 'grafana-pv' | \
		xargs -r -n1 kubectl delete --ignore-not-found --wait=false >/dev/null 2>&1 || true

	# Namespace (and strip finalizers if stuck)
	-@kubectl delete namespace monitoring --ignore-not-found --wait=false >/dev/null 2>&1 || true
	-@kubectl patch namespace monitoring --type=merge -p '{"spec":{"finalizers":[]}}' >/dev/null 2>&1 || true

# Removes K8s/Helm resources from Terraform state to avoid errors on destroy
_state_rm_k8s:
	@echo "$(YELLOW)🧺 Removing K8s/Helm resources from Terraform state$(RESET)"
	-@$(TF) state rm module.grafana.helm_release.grafana >/dev/null 2>&1 || true
	-@$(TF) state rm module.grafana.kubernetes_persistent_volume.grafana_pv >/dev/null 2>&1 || true
	-@$(TF) state rm module.grafana.kubernetes_namespace.monitoring >/dev/null 2>&1 || true
	-@$(TF) state rm helm_release.aws_load_balancer_controller >/dev/null 2>&1 || true
	-@$(TF) state rm kubernetes_config_map.aws_logging >/dev/null 2>&1 || true
	# Fallback: strip any other lingering k8s/helm entries
	-@$(TF) state list 2>/dev/null | egrep '^(helm_release|kubernetes_)' | xargs -r $(TF) state rm >/dev/null 2>&1 || true

# Cleans up leftover AWS network resources (ALBs/ENIs) before destroy
_aws_net_purge:
	@echo "$(YELLOW)🧼 Pre-cleaning LBs, ENIs, SGs$(RESET)"
	@set -eu; \
	REGION="$$(terraform output -raw region 2>/dev/null || true)"; \
	[ -z "$$REGION" ] && REGION="$${AWS_REGION:-$${AWS_DEFAULT_REGION:-us-east-1}}"; \
	VPC_ID="$$(terraform output -raw vpc_id 2>/dev/null || true)"; \
	if [ -z "$$VPC_ID" ] || [ "$$VPC_ID" = "None" ]; then \
	  VPC_ID="$$(aws eks describe-cluster --name final-eks-cluster --region $$REGION \
	    --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null || true)"; \
	fi; \
	if [ -z "$$VPC_ID" ] || [ "$$VPC_ID" = "None" ]; then \
	  echo "$(YELLOW)↪ No VPC ID found. Skipping purge.$(RESET)"; exit 0; \
	fi; \
	echo "  → region=$$REGION vpc=$$VPC_ID"; \
	\
	echo "  #1  Deleting ALBs/NLBs..."; \
	aws elbv2 describe-load-balancers --region $$REGION \
	  --query "LoadBalancers[?VpcId=='$$VPC_ID'].LoadBalancerArn" --output text 2>/dev/null | \
	xargs -r -n1 aws elbv2 delete-load-balancer --region $$REGION --load-balancer-arn >/dev/null 2>&1 || true; \
	\
	echo "  #2  Cleaning ENIs..."; \
	for eni in $$(aws ec2 describe-network-interfaces --region $$REGION \
	      --filters Name=vpc-id,Values=$$VPC_ID \
	      --query 'NetworkInterfaces[].{Id:NetworkInterfaceId,Att:Attachment.AttachmentId}' \
	      --output text 2>/dev/null); do \
	  set -- $$eni; ENI=$$1; ATT=$$2; \
	  [ -n "$$ATT" ] && [ "$$ATT" != "None" ] && \
	    aws ec2 detach-network-interface --region $$REGION --attachment-id "$$ATT" >/dev/null 2>&1 || true; \
	  aws ec2 delete-network-interface --region $$REGION --network-interface-id "$$ENI" >/dev/null 2>&1 || true; \
	done; \
	\
	echo "  #3  Removing non-default Security Groups..."; \
	for sg in $$(aws ec2 describe-security-groups --region $$REGION \
	      --filters Name=vpc-id,Values=$$VPC_ID \
	      --query "SecurityGroups[?GroupName!='default'].GroupId" \
	      --output text 2>/dev/null); do \
	  ING=$$(aws ec2 describe-security-groups --region $$REGION --group-ids $$sg \
	        --query 'SecurityGroups[0].IpPermissions' --output json 2>/dev/null); \
	  [ "$$ING" != "[]" ] && aws ec2 revoke-security-group-ingress --region $$REGION --group-id $$sg --ip-permissions "$$ING" >/dev/null 2>&1 || true; \
	  EGR=$$(aws ec2 describe-security-groups --region $$REGION --group-ids $$sg \
	        --query 'SecurityGroups[0].IpPermissionsEgress' --output json 2>/dev/null); \
	  [ "$$EGR" != "[]" ] && aws ec2 revoke-security-group-egress  --region $$REGION --group-id $$sg --ip-permissions "$$EGR" >/dev/null 2>&1 || true; \
	  aws ec2 delete-security-group --region $$REGION --group-id $$sg >/dev/null 2>&1 || true; \
	done; \
	\
	echo "  #4  Removing VPC Endpoints..."; \
	EP=$$(aws ec2 describe-vpc-endpoints --region $$REGION --filters Name=vpc-id,Values=$$VPC_ID \
	     --query 'VpcEndpoints[].VpcEndpointId' --output text 2>/dev/null); \
	[ -n "$$EP" ] && aws ec2 delete-vpc-endpoints --region $$REGION --vpc-endpoint-ids $$EP >/dev/null 2>&1 || true; \
	\
	echo "  #5  Cleaning NAT & IGWs..."; \
	for ngw in $$(aws ec2 describe-nat-gateways --region $$REGION --filter Name=vpc-id,Values=$$VPC_ID \
	      --query 'NatGateways[].NatGatewayId' --output text 2>/dev/null); do \
	  aws ec2 delete-nat-gateway --region $$REGION --nat-gateway-id $$ngw >/dev/null 2>&1 || true; \
	done; \
	IGW=$$(aws ec2 describe-internet-gateways --region $$REGION --filters Name=attachment.vpc-id,Values=$$VPC_ID \
	      --query 'InternetGateways[].InternetGatewayId' --output text 2>/dev/null); \
	[ -n "$$IGW" ] && aws ec2 detach-internet-gateway --region $$REGION --internet-gateway-id $$IGW --vpc-id $$VPC_ID >/dev/null 2>&1 || true; \
	[ -n "$$IGW" ] && aws ec2 delete-internet-gateway --region $$REGION --internet-gateway-id $$IGW >/dev/null 2>&1 || true; \
	\
	echo "  #6  Resetting DHCP options (if not default)..."; \
	DHCP=$$(aws ec2 describe-vpcs --region $$REGION --vpc-ids $$VPC_ID --query 'Vpcs[0].DhcpOptionsId' --output text 2>/dev/null); \
	[ "$$DHCP" != "default" ] && aws ec2 associate-dhcp-options --region $$REGION --dhcp-options-id default --vpc-id $$VPC_ID >/dev/null 2>&1 || true; \
	echo "$(GREEN)✅ AWS network pre-clean complete$(RESET)"

# Confirms IP to use for EKS API access and saves to .make_env_public_access
_confirm_ip:
	@IP="$$(curl -s https://checkip.amazonaws.com)"; \
	TFVARS_IP="$$(grep -E 'public_access_cidrs' $(TFVARS) 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/32' | head -n1)"; \
	echo "🌐 Detected current public IP: $$IP"; \
	if [ -n "$$TFVARS_IP" ]; then \
	  echo "🗂  IP configured in $(TFVARS): $$TFVARS_IP"; \
	else \
	  echo "⚠️  No public_access_cidrs found in $(TFVARS)"; \
	fi; \
	read -r -p "Use the IP from $(TFVARS) (y/N)? " USE_TFVARS; \
	case "$$USE_TFVARS" in \
	  [yY]) CIDR="$$TFVARS_IP";; \
	  *) read -r -p "Enter IP/CIDR to use (detected $$IP/32): " CIDR; \
	     [ -z "$$CIDR" ] && CIDR="$$IP/32";; \
	esac; \
	printf "export TF_VAR_public_access_cidrs='[\"%s\"]'\n" "$$CIDR" > .make_env_public_access; \
	echo "✅ Will allow $$CIDR (saved to .make_env_public_access)"

# Initializes Terraform with backend and all modules found in modules/ (Not including .* dirs)
init: _guard_backend
	@echo "$(YELLOW)🚀 Initializing Terraform (root) with backend $(BACKEND)$(RESET)"
	@$(TF) init -upgrade -reconfigure -backend-config=$(BACKEND)
	@echo "$(YELLOW)🔁 Initializing all modules...$(RESET)"
	@for dir in $$(find modules -mindepth 1 -maxdepth 1 -type d ! -name ".*"); do \
		echo "$(YELLOW)→ Initializing $$dir$(RESET)"; \
		cd $$dir && $(TF) init -upgrade >/dev/null && cd - >/dev/null; \
	done
	@echo "$(YELLOW)✅ All Terraform modules initialized$(RESET)"

# Terraform plan using env tfvars and outputs to plan file
plan: _guard_tfvars
	@echo "$(YELLOW)🧠 Planning for $(ENV)$(RESET)"
	$(MAKE) _confirm_ip
	@. ./.make_env_public_access; \
	$(TF) plan -var-file=$(TFVARS) -out=plan-$(ENV).tfplan

# Applies previously generated plan file
apply:
	@echo "$(GREEN)🚀 Applying plan for $(ENV)$(RESET)"
	$(TF) apply "plan-$(ENV).tfplan"

# Destroy resources for the selected environment including above pre-cleanup steps
destroy: _guard_tfvars
	@echo "$(YELLOW)💣 Destroying $(ENV)$(RESET)"
	$(MAKE) _aws_net_purge
	$(MAKE) _force_k8s_purge
	$(MAKE) _state_rm_k8s
	@TF_LOG=DEBUG TF_LOG_PATH=./tf.log \
	  $(TF) destroy -var-file=$(TFVARS) -refresh=true -lock-timeout=5m

# Validates Terraform configuration syntax at root
validate:
	@echo "$(YELLOW)🔍 Validating$(RESET)"
	$(TF) validate

# ==============================
# Quality & Docs
# ==============================

# Formats your Terraform files
fmt:
	@echo "$(YELLOW)🧹 Formatting$(RESET)"
	$(TF) fmt -recursive

# Runs pre-commit hooks against all files
lint:
	@echo "$(YELLOW)🔎 Running pre-commit hooks$(RESET)"
	pre-commit run --all-files

# Generates terraform-docs for all modules in modules/
docs:
	@echo "$(YELLOW)📘 Generating module documentation$(RESET)"
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
	@echo "$(YELLOW)🧽 Cleaning$(RESET)"
	rm -rf .terraform .terraform.lock.hcl plan-*.tfplan

# Displays help information
help:
	@echo "$(GREEN)Available targets:$(RESET)"
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
