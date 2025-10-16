# ==============================
# Makefile for Terraform Project
# ==============================

# Default Terraform settings
TF := terraform

# Colors for readability
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RESET  := \033[0m

# If ENV is not provided, prompt the user interactively
ifeq ($(strip $(ENV)),)
ENV := $(shell read -p "🌎 Please enter environment (dev/test/prod): " env; echo $$env)
endif

TF_DIR ?= envs/$(ENV)
TFVARS ?= $(TF_DIR)/terraform.tfvars
BACKEND ?= $(TF_DIR)/backend.tfvars

# ==============================
# Terraform Core Commands
# ==============================

init:
	@echo "$(YELLOW)🚀 Initializing Terraform for environment: $(ENV)$(RESET)"
	@if [ -f "$(BACKEND)" ]; then \
	  $(TF) -chdir=$(TF_DIR) init -backend-config="$(BACKEND)"; \
	else \
	  $(TF) -chdir=$(TF_DIR) init; \
	fi

plan:
	@echo "$(YELLOW)🧩 Generating Terraform plan for environment: $(ENV)$(RESET)"
	$(TF) -chdir=$(TF_DIR) plan \
		-var-file="$(TFVARS)" \
		-out="plan-$(ENV).tfplan"

apply:
	@echo "$(GREEN)🚀 Applying Terraform changes for environment: $(ENV)$(RESET)"
	$(TF) -chdir=$(TF_DIR) apply "plan-$(ENV).tfplan"

destroy:
	@echo "$(YELLOW)💣 Destroying Terraform resources for environment: $(ENV)$(RESET)"
	$(TF) -chdir=$(TF_DIR) destroy \
		-var-file="$(TFVARS)" \
		-auto-approve

validate:
	@echo "$(YELLOW)🔍 Validating Terraform configuration for $(ENV)$(RESET)"
	$(TF) -chdir=$(TF_DIR) validate

fmt:
	@echo "$(YELLOW)🧹 Formatting Terraform files$(RESET)"
	$(TF) fmt -recursive

# ==============================
# Quality & Docs
# ==============================

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
