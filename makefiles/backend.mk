# The backend component.

BACKEND_WORKFLOW ?= ci-cd.yml

##@ Deploy

.PHONY: backend
backend: ## Build and deploy the backend, wait for its health check
	@$(call dispatch,$(BACKEND_REPO),$(BACKEND_WORKFLOW),backend)
