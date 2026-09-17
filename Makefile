# Drives the three deployment pipelines from a workstation.
#
# Nothing here deploys anything. Every deployment target dispatches a GitHub
# workflow and follows its run, so the work happens on a runner, under the OIDC
# trust that is already in place, and no Azure credential is needed locally.

SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
MAKEFLAGS += --no-print-directory
.DEFAULT_GOAL := help

# Override on the command line, never through the environment: a variable
# assigned in a makefile wins over an exported one, so `ORG=x make deploy` is
# silently ignored while `make deploy ORG=x` works.
ORG             ?= Melvin-Simplon
INFRA_REPO      ?= capstone-quiz-infrastructure
BACKEND_REPO    ?= capstone-quiz-backend
FRONTEND_REPO   ?= capstone-quiz-frontend

RESOURCE_GROUP  ?= mpetitRG
SUBSCRIPTION_ID ?= 5e683e0f-b00c-48d6-9769-5aaf598de8f1
TENANT_ID       ?= a2e466aa-4f86-4545-b5b8-97da7c8febf3
OIDC_APP_NAME   ?= github-oidc-simplon-quiz-bilan

TF_ORG          ?= WhiteMuush-Organizations
TF_WORKSPACE    ?= simplon-quiz-nonprod

PIPELINE        := scripts/pipeline

# Read by the scripts rather than passed as arguments: they all need the same
# handful of values, and threading them through every call site adds noise
# without adding clarity.
export ORG INFRA_REPO BACKEND_REPO FRONTEND_REPO
export RESOURCE_GROUP SUBSCRIPTION_ID TENANT_ID OIDC_APP_NAME
export TF_ORG TF_WORKSPACE

include makefiles/component.mk
include makefiles/infra.mk
include makefiles/backend.mk
include makefiles/frontend.mk
include makefiles/common.mk
