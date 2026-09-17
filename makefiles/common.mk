# Everything not tied to one component: the checks, the orchestration, the help.

##@ Setup

.PHONY: doctor
doctor: ## Check every prerequisite and report what is missing
	@$(PIPELINE)/doctor.sh

.PHONY: bootstrap
bootstrap: ## Repair the OIDC trust, the roles and the repository variables
	@scripts/bootstrap-oidc.sh

##@ Deploy

# Sequential through recursive make rather than a prerequisite list: make is
# free to reorder prerequisites, and the order is the whole point here. The
# infrastructure has to exist before anything is deployed onto it, the backend
# has to answer before the frontend pipeline verifies it, and the frontend has
# to be rebuilt after any infrastructure rebuild because the API key it bakes
# in is regenerated whenever the vault is recreated.
.PHONY: deploy
deploy: ## Deploy everything in order: infra, backend, frontend
	@$(MAKE) infra
	@$(MAKE) backend
	@$(MAKE) frontend

.PHONY: one-shot
one-shot: ## Everything from an empty environment, resumable after a failure
	@$(MAKE) doctor
	@$(MAKE) bootstrap
	@$(MAKE) deploy

##@ Inspect

.PHONY: status
status: ## Show the last run of each repository and the deployed URLs
	@$(PIPELINE)/status.sh

.PHONY: logs
logs: ## Follow the run currently in progress
	@$(PIPELINE)/status.sh --follow

##@ Help

.PHONY: lint
lint: ## Run shellcheck over the scripts
	@shellcheck -x scripts/*.sh $(PIPELINE)/*.sh && echo "shellcheck: clean"

.PHONY: help
help: ## Print this help
	@$(PIPELINE)/help.sh
