# The frontend component.

# The frontend split ci-cd.yml into ci.yml and cd.yml. Deployment lives in
# the second one, and it is the one that declares workflow_dispatch.
FRONTEND_WORKFLOW ?= cd.yml

.PHONY: frontend
frontend: ## Build and deploy the frontend, verify the site answers
	@$(call dispatch,$(FRONTEND_REPO),$(FRONTEND_WORKFLOW),frontend)
