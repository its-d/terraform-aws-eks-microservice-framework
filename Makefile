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

# Guards
_guard_tfvars:
	@if [ ! -f "$(TFVARS)" ]; then \
		echo "$(YELLOW)Missing $(TFVARS). Create it or set ENV=<env>$(RESET)"; \
		exit 1; \
	fi

_guard_backend:
	@if [ ! -f "$(BACKEND)" ]; then \
		echo "$(YELLOW)Missing $(BACKEND). Create it (S3/Dynamo backend config) or set ENV=<env>$(RESET)"; \
		exit 1; \
	fi

# --- Hard nuke of local K8s bits used by Grafana (best-effort) ---
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

# --- Remove K8s/Helm resources from TF state so destroy doesn't hit the K8s provider ---
_state_rm_k8s:
	@echo "$(YELLOW)🧺 Removing K8s/Helm resources from Terraform state$(RESET)"
	-@$(TF) state rm module.grafana.helm_release.grafana >/dev/null 2>&1 || true
	-@$(TF) state rm module.grafana.kubernetes_persistent_volume.grafana_pv >/dev/null 2>&1 || true
	-@$(TF) state rm module.grafana.kubernetes_namespace.monitoring >/dev/null 2>&1 || true
	-@$(TF) state rm helm_release.aws_load_balancer_controller >/dev/null 2>&1 || true
	-@$(TF) state rm kubernetes_config_map.aws_logging >/dev/null 2>&1 || true
	# Fallback: strip any other lingering k8s/helm entries
	-@$(TF) state list 2>/dev/null | egrep '^(helm_release|kubernetes_)' | xargs -r $(TF) state rm >/dev/null 2>&1 || true


init: _guard_backend  ## Initialize Terraform in root and all module folders (skip hidden dirs)
	@echo "$(YELLOW)🚀 Initializing Terraform (root) with backend $(BACKEND)$(RESET)"
	@$(TF) init -upgrade -reconfigure -backend-config=$(BACKEND)
	@echo "$(YELLOW)🔁 Initializing all modules...$(RESET)"
	@for dir in $$(find modules -mindepth 1 -maxdepth 1 -type d ! -name ".*"); do \
		echo "$(YELLOW)→ Initializing $$dir$(RESET)"; \
		cd $$dir && $(TF) init -upgrade >/dev/null && cd - >/dev/null; \
	done
	@echo "$(YELLOW)✅ All Terraform modules initialized$(RESET)"

plan: _guard_tfvars ## terraform plan using env tfvars
	@echo "$(YELLOW)🧠 Planning for $(ENV)$(RESET)"
	$(TF) plan -var-file=$(TFVARS) -out=plan-$(ENV).tfplan

apply: ## apply last plan file
	@echo "$(GREEN)🚀 Applying plan for $(ENV)$(RESET)"
	$(TF) apply "plan-$(ENV).tfplan"

# --- Your destroy, now with the two steps above first ---
destroy: _guard_tfvars
	@echo "$(YELLOW)💣 Destroying $(ENV)$(RESET)"
	$(MAKE) _force_k8s_purge
	$(MAKE) _state_rm_k8s
	@$(TF) destroy -var-file=$(TFVARS)

validate: ## terraform validate (root)
	@echo "$(YELLOW)🔍 Validating$(RESET)"
	$(TF) validate

clean: ## remove local artifacts
	@echo "$(YELLOW)🧽 Cleaning$(RESET)"
	rm -rf .terraform .terraform.lock.hcl plan-*.tfplan

# ==============================
# Quality & Docs
# ==============================

fmt: ## format
	@echo "$(YELLOW)🧹 Formatting$(RESET)"
	$(TF) fmt -recursive

lint:
	@echo "$(YELLOW)🔎 Running pre-commit hooks$(RESET)"
	pre-commit run --all-files

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

clean:
	@echo "$(YELLOW)🧽 Cleaning up local files$(RESET)"
	rm -rf .terraform .terraform.lock.hcl plan-*.tfplan

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
