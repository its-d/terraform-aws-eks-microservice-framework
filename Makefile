# ==============================
# Makefile (root-driven Terraform)
# ==============================
.ONESHELL:
SHELL := /bin/bash

TFVARS  ?= terraform.tfvars
BACKEND ?= backend.hcl
TF      := terraform

_guard_tfvars:
	@{ \
	  set -euo pipefail; \
	  if [ ! -f "$(TFVARS)" ]; then \
	    echo "Missing $(TFVARS). Copy terraform.tfvars.example and edit."; \
	    exit 1; \
	  fi; \
	}

_guard_backend:
	@{ \
	  set -euo pipefail; \
	  if [ ! -f "$(BACKEND)" ]; then \
	    echo "Missing $(BACKEND). Copy backend.hcl.example and edit."; \
	    exit 1; \
	  fi; \
	}

# Prompt for Grafana credentials if not set; create Secrets Manager secrets and update tfvars
_setup_grafana_if_needed:
	@if [ ! -f "$(TFVARS)" ]; then cp terraform.tfvars.example $(TFVARS) 2>/dev/null || true; fi; \
	HAS_ARN=$$(grep -E 'grafana_admin_user_arn.*=.*"arn:aws:secretsmanager' $(TFVARS) 2>/dev/null | wc -l); \
	if [ "$$HAS_ARN" -eq 0 ]; then \
	  echo "============================> Grafana credentials not configured"; \
	  export TFVARS; \
	  bash scripts/setup-grafana-secrets.sh; \
	fi

# Optional: confirm IP for EKS API access (use when restricting public_access_cidrs)
confirm-ip:
	@IP="$$(curl -s https://checkip.amazonaws.com 2>/dev/null || echo "unknown")"; \
	echo "Detected IP: $$IP"; \
	read -r -p "Enter CIDR to allow (e.g. $$IP/32): " CIDR; \
	[ -z "$$CIDR" ] && CIDR="$$IP/32"; \
	echo "Update public_access_cidrs = [\"$$CIDR\"] in $(TFVARS)"

# --- Core ---
init: _guard_backend
	@echo "🚀 Initializing Terraform with backend $(BACKEND)"
	@$(TF) init -upgrade -reconfigure -backend-config=$(BACKEND)
	@echo "============================> Terraform initialized"

plan: _guard_tfvars
	@$(MAKE) -s _setup_grafana_if_needed
	@echo "============================> Planning"
	@$(TF) plan -var-file=$(TFVARS) -out=plan.tfplan

apply:
	@echo "============================> Applying"
	@$(TF) apply "plan.tfplan"

destroy: _guard_tfvars
	@echo "============================> Pre-destroy cleanup"
	@bash scripts/pre-destroy-cleanup.sh
	@echo "============================> Removing VPC from state (prevents DependencyViolation)"
	@bash scripts/state-rm-vpc.sh
	@echo "============================> Destroying"
	@$(TF) destroy -var-file=$(TFVARS) -refresh=true -lock-timeout=5m
	@echo "============================> Force-deleting orphaned VPC"
	@bash scripts/force-delete-vpc.sh

# Re-run cleanup and destroy (use when destroy failed on VPC DependencyViolation)
destroy-retry: _guard_tfvars
	@echo "============================> Retry: pre-destroy cleanup"
	@bash scripts/pre-destroy-cleanup.sh
	@echo "============================> Removing VPC from state"
	@bash scripts/state-rm-vpc.sh
	@echo "============================> Destroying"
	@$(TF) destroy -var-file=$(TFVARS) -refresh=true -lock-timeout=5m
	@echo "============================> Force-deleting orphaned VPC"
	@bash scripts/force-delete-vpc.sh

# --- Utility ---
validate:
	@echo "============================> Validating"
	@$(TF) validate

outputs:
	@$(TF) output 2>/dev/null || echo "No outputs (run apply first)"

grafana-url:
	@echo "Grafana URL: Get from AWS Console -> EC2 -> Load Balancers (ALB for monitoring namespace)"
	@$(TF) output -raw cluster_name 2>/dev/null && echo "Cluster: $$(terraform output -raw cluster_name)" || true

# --- Quality ---
fmt:
	@echo "============================> Formatting"
	@$(TF) fmt -recursive

lint:
	@echo "============================> Running pre-commit"
	@pre-commit run --all-files

docs:
	@echo "============================> Generating module docs"
	@for d in modules/*; do \
	  [ -d "$$d" ] && terraform-docs markdown table $$d > $$d/README.md 2>/dev/null || true; \
	done

# --- Tests ---
test:
	@echo "============================> Running Terraform tests"
	@for dir in modules/vpc modules/iam modules/iam_irsa modules/eks; do \
	  [ -d "$$dir" ] && [ -n "$$(find $$dir -maxdepth 1 -name '*.tftest.hcl' -print -quit)" ] && \
	    (cd $$dir && $(TF) init -backend=false -input=false >/dev/null && $(TF) test) || true; \
	done
	@echo "============================> Tests complete"

# --- Clean ---
clean:
	@echo "============================> Cleaning"
	@rm -rf .terraform .terraform.lock.hcl plan*.tfplan

# --- Help ---
help:
	@echo "Available targets:"
	@echo ""
	@echo "Core:"
	@echo "  init    - Initialize Terraform (requires backend.hcl)"
	@echo "  plan    - Plan (prompts for Grafana creds if needed)"
	@echo "  apply   - Apply plan"
	@echo "  destroy       - Pre-cleanup + destroy"
	@echo "  destroy-retry - Re-cleanup + destroy (when VPC DependencyViolation)"
	@echo ""
	@echo "Utility:"
	@echo "  outputs     - Show Terraform outputs"
	@echo "  grafana-url - Show Grafana access info"
	@echo "  validate    - Validate config"
	@echo "  fmt         - Format Terraform files"
	@echo "  lint        - Run pre-commit"
	@echo "  docs        - Generate module docs"
	@echo "  test        - Run Terraform tests"
	@echo "  clean       - Remove caches and plan files"
	@echo ""
	@echo "Optional:"
	@echo "  confirm-ip  - Helper to set public_access_cidrs"

.PHONY: init plan apply destroy destroy-retry validate fmt lint docs test clean help outputs grafana-url confirm-ip _guard_tfvars _guard_backend _setup_grafana_if_needed
.DEFAULT_GOAL := help
