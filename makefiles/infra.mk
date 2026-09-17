# The infrastructure component, plus the two targets no other component has.

INFRA_WORKFLOW         ?= terraform.yml
INFRA_DESTROY_WORKFLOW ?= terraform-destroy.yml

##@ Deploy

.PHONY: infra
infra: ## Apply the Terraform configuration
	@$(call dispatch,$(INFRA_REPO),$(INFRA_WORKFLOW),infra,action=apply)

##@ Inspect

.PHONY: plan
plan: ## Run a Terraform plan and print it
	@$(call dispatch,$(INFRA_REPO),$(INFRA_WORKFLOW),plan,action=plan) --print-log

##@ Teardown

.PHONY: destroy
destroy: ## Tear the environment down, asking for the resource group name
	@$(PIPELINE)/destroy.sh \
	    --repo "$(ORG)/$(INFRA_REPO)" \
	    --workflow "$(INFRA_DESTROY_WORKFLOW)"
