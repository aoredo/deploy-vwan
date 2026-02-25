.PHONY: help init plan apply destroy fmt validate clean setup-state

TERRAFORM := terraform
TF_PLAN_FILE := tfplan
SHELL := /bin/bash

help: ## Display this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform working directory
	$(TERRAFORM) init -upgrade

validate: ## Validate Terraform configuration
	$(TERRAFORM) validate

fmt: ## Format Terraform files
	$(TERRAFORM) fmt -recursive -diff

fmt-fix: ## Format and fix Terraform files
	$(TERRAFORM) fmt -recursive

plan: validate ## Plan infrastructure changes
	$(TERRAFORM) plan -out=$(TF_PLAN_FILE)

plan-destroy: validate ## Plan infrastructure destruction
	$(TERRAFORM) plan -destroy -out=$(TF_PLAN_FILE)

apply: ## Apply Terraform changes
	@if [ ! -f $(TF_PLAN_FILE) ]; then \
		echo "No plan file found. Run 'make plan' first."; \
		exit 1; \
	fi
	$(TERRAFORM) apply $(TF_PLAN_FILE)
	@rm -f $(TF_PLAN_FILE)

destroy: ## Destroy all infrastructure (use with caution)
	@echo "WARNING: This will destroy all infrastructure!"
	@echo "Press CTRL+C to cancel, or ENTER to continue..."
	@read dummy
	$(TERRAFORM) destroy

output: ## Display Terraform outputs
	$(TERRAFORM) output

refresh: ## Refresh Terraform state
	$(TERRAFORM) refresh

show: ## Show current Terraform state
	$(TERRAFORM) show

state-list: ## List all resources in state
	$(TERRAFORM) state list

state-show: ## Show specific resource state
	@read -p "Enter resource address: " resource; \
	$(TERRAFORM) state show $$resource

fmt-check: ## Check if files are formatted
	$(TERRAFORM) fmt -recursive -check

clean: ## Clean Terraform temporary files
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f $(TF_PLAN_FILE)
	rm -f crash.log

setup-state: ## Setup Azure storage backend for state
	@chmod +x scripts/setup_state.sh
	@./scripts/setup_state.sh

setup-devops: ## Setup Azure DevOps pipeline and integration
	@chmod +x scripts/setup_devops.sh
	@./scripts/setup_devops.sh

console: ## Open Terraform console
	$(TERRAFORM) console

tainted: ## List tainted resources
	$(TERRAFORM) state list | grep tainted

untaint: ## Untaint all resources
	@$(TERRAFORM) state list | xargs -I {} bash -c '$(TERRAFORM) untaint "$${1}" || true' -- {}

version: ## Display Terraform version
	$(TERRAFORM) version

docs: ## Display README documentation
	@cat README.md

workspace-list: ## List Terraform workspaces
	$(TERRAFORM) workspace list

workspace-new: ## Create new Terraform workspace
	@read -p "Enter workspace name: " ws_name; \
	$(TERRAFORM) workspace new $$ws_name

workspace-select: ## Select Terraform workspace
	@read -p "Enter workspace name: " ws_name; \
	$(TERRAFORM) workspace select $$ws_name

graph: ## Generate resource dependency graph
	@$(TERRAFORM) graph > graph.dot
	@echo "Graph saved to graph.dot"
	@echo "To visualize: dot -Tpng graph.dot -o graph.png"

test-connections: ## Test connectivity to deployed resources
	@echo "Testing vWAN Hub..."
	@az network vwan show --resource-group $$($(TERRAFORM) output -raw resource_group_name) --name $$($(TERRAFORM) output -raw vwan_name) -o table
	@echo "Testing Firewall..."
	@az firewall show --resource-group $$($(TERRAFORM) output -raw resource_group_name) --name $$($(TERRAFORM) output -json | grep -o '"firewall_name"[^,]*' | cut -d'"' -f4) -o table

cost-estimate: ## Estimate monthly cost (requires infracost)
	@if command -v infracost &> /dev/null; then \
		infracost breakdown --path . --format table; \
	else \
		echo "infracost not installed. See https://www.infracost.io/docs/"; \
	fi

security-check: ## Run Terraform security checks (requires tfsec)
	@if command -v tfsec &> /dev/null; then \
		tfsec . --format sarif > tfsec-report.sarif; \
		echo "Security scan complete. Report saved to tfsec-report.sarif"; \
	else \
		echo "tfsec not installed. See https://www.terraform.io/"; \
	fi

lint: fmt-check validate ## Run all linting checks

all: clean init validate plan ## Run full cycle without apply

.DEFAULT_GOAL := help
