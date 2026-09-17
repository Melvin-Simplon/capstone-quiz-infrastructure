# The frontend component.

FRONTEND_WORKFLOW ?= ci-cd.yml

.PHONY: frontend
frontend: ## Build and deploy the frontend, verify the site answers
	@$(call dispatch,$(FRONTEND_REPO),$(FRONTEND_WORKFLOW),frontend)
