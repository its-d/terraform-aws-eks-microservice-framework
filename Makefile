# ==============================
# Makefile (root-driven Terraform)
# ==============================

ENV ?= dev
TFVARS ?= envs/$(ENV)/terraform.tfvars
TF := terraform

GREEN  := \033[0;32m
YELLOW := \033[1;33m
RESET  := \033[0m

# Guard: require TFVARS to exist
_guard_tfvars:
	@if [ ! -f "$(TFVARS)" ]; then \
		echo "$(YELLOW)Missing $(TFVARS). Create it or set ENV=<env>$(RESET)"; \
		exit 1; \
	fi

init:  ## terraform init at repo root
	@echo "$(YELLOW)🚀 Initializing Terraform (root)$(RESET)"
	$(TF) init -upgrade
	cd modules/iam && $(TF) init -upgrade
	cd modules/iam_irsa && $(TF) init -upgrade
	cd modules/vpc %% $(TF) init -upgrade
	cd modules/eks && $(TF) init -upgrade
	cd modules/security && $(TF) init -upgrade

plan: _guard_tfvars ## terraform plan using env tfvars
	@echo "$(YELLOW)🧠 Planning for $(ENV)$(RESET)"
	$(TF) plan -var-file=$(TFVARS) -out=plan-$(ENV).tfplan

apply: ## apply last plan file
	@echo "$(GREEN)🚀 Applying plan for $(ENV)$(RESET)"
	$(TF) apply "plan-$(ENV).tfplan"

destroy: _guard_tfvars ## destroy using env tfvars
	@echo "$(YELLOW)💣 Destroying $(ENV)$(RESET)"
	$(TF) destroy -var-file=$(TFVARS)

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
	@echo "  init        - Initialize Terraform backend/config for the selected environment"
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
