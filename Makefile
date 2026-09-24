SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
MAKEFLAGS += --no-print-directory
.DEFAULT_GOAL := help

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

LOG_FILE        ?= .logs/pipeline.log

PIPELINE        := scripts/pipeline

export ORG INFRA_REPO BACKEND_REPO FRONTEND_REPO
export RESOURCE_GROUP SUBSCRIPTION_ID TENANT_ID OIDC_APP_NAME
export TF_ORG TF_WORKSPACE LOG_FILE

include makefiles/component.mk
include makefiles/infra.mk
include makefiles/backend.mk
include makefiles/frontend.mk
include makefiles/common.mk
