#!/usr/bin/env bash
# Grants GitHub Actions the right to deploy this infrastructure, without any
# long lived secret: the workflow exchanges a short lived GitHub token for an
# Azure one.
#
# This is bootstrap work, deliberately outside Terraform. The identity that runs
# Terraform cannot be created by the Terraform it runs.
#
# Run once, from an account holding Owner and Role Based Access Control
# Administrator on the target scopes.

set -euo pipefail

APP_NAME="github-oidc-simplon-quiz-bilan"
OWNER="WhiteMuush"

# One identity for the three repositories rather than three: the trust is carried
# by the federated credentials below, one per repository and per context, so a
# shared app registration grants nothing a separate one would have withheld.
INFRA_REPO="simplon-quiz-infrastructure-bilan"
BACKEND_REPO="simplon-quiz-backend-bilan"
FRONTEND_REPO="simplon-quiz-frontend-bilan"
SUBSCRIPTION_ID="5e683e0f-b00c-48d6-9769-5aaf598de8f1"
RESOURCE_GROUP="mpetitRG"
STATE_ACCOUNT="sttfstatempetit"

echo "==> Application registration"
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [ -z "$APP_ID" ]; then
  APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
  echo "    created: $APP_ID"
else
  echo "    already there: $APP_ID"
fi

az ad sp show --id "$APP_ID" >/dev/null 2>&1 || az ad sp create --id "$APP_ID" >/dev/null
SP_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)

echo "==> Federated credentials"
# GitHub now issues immutable subjects, carrying the numeric ids of the account
# and of the repository rather than their names. Asking the API for the prefix
# it actually signs avoids guessing which form is in use, and keeps working if
# that form changes again.
subject_prefix_of() {
  local repo="$1" prefix
  prefix=$(gh api "repos/${OWNER}/${repo}/actions/oidc/customization/sub" --jq '.sub_claim_prefix' 2>/dev/null || true)
  [ -z "$prefix" ] && prefix="repo:${OWNER}/${repo}"
  echo "$prefix"
}

# One subject per trusted context. Anything else, another branch or another
# repository, gets no token at all.
add_federated_credential() {
  local name="$1" subject="$2" current
  current=$(az ad app federated-credential list --id "$APP_ID" --query "[?name=='$name'].subject | [0]" -o tsv)

  if [ "$current" = "$subject" ]; then
    echo "    $name already there"
    return
  fi

  if [ -n "$current" ]; then
    az ad app federated-credential delete --id "$APP_ID" --federated-credential-id "$name"
    echo "    $name had a stale subject, recreating"
  fi

  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"$name\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"$subject\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" >/dev/null
  echo "    $name created"
}

# Credentials are named after the repository they trust. The infrastructure ones
# predate that convention and keep their original names: renaming them means
# deleting credentials that work, to gain nothing but symmetry.
trust_repository() {
  local repo="$1" main_name="$2" pr_name="$3" env_name="$4" sub
  sub=$(subject_prefix_of "$repo")
  echo "    $repo subject prefix: $sub"

  add_federated_credential "$main_name" "${sub}:ref:refs/heads/main"
  add_federated_credential "$pr_name" "${sub}:pull_request"
  add_federated_credential "$env_name" "${sub}:environment:nonprod"
}

trust_repository "$INFRA_REPO" "main-branch" "pull-request" "nonprod-environment"
trust_repository "$BACKEND_REPO" "backend-main-branch" "backend-pull-request" "backend-nonprod-environment"
trust_repository "$FRONTEND_REPO" "frontend-main-branch" "frontend-pull-request" "frontend-nonprod-environment"

echo "==> Role assignments"
assign() {
  local role="$1" scope="$2"
  az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
    --role "$role" --scope "$scope" >/dev/null 2>&1 \
    && echo "    $role granted" \
    || echo "    $role already there"
}

# Scoped to the dedicated resource group, never the subscription.
assign "Contributor" "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"

# Terraform hands the backend's managed identity its roles on Key Vault and on
# the storage container, and grants itself the one that lets it write secrets.
# Creating a role assignment is not something Contributor may do, hence this.
assign "Role Based Access Control Administrator" \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"

# The state account has shared key access disabled, so reaching the state needs
# a data plane role. Control plane rights alone would not open the blob.
assign "Storage Blob Data Contributor" \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${STATE_ACCOUNT}"

echo "==> GitHub repository variables"
# Variables and not secrets: none of these three values is confidential, and
# masking them in the logs only makes failures harder to read.
TENANT_ID=$(az account show --query tenantId -o tsv)
for repo in "$INFRA_REPO" "$BACKEND_REPO" "$FRONTEND_REPO"; do
  gh variable set AZURE_CLIENT_ID --repo "${OWNER}/${repo}" --body "$APP_ID"
  gh variable set AZURE_TENANT_ID --repo "${OWNER}/${repo}" --body "$TENANT_ID"
  gh variable set AZURE_SUBSCRIPTION_ID --repo "${OWNER}/${repo}" --body "$SUBSCRIPTION_ID"
  echo "    ${repo} set"
done

echo "==> Deployment environments"
# A deployment becomes an event with a name and a history, instead of a side
# effect of a merge. It is also the context one of the federated credentials
# above is bound to.
for repo in "$BACKEND_REPO" "$FRONTEND_REPO"; do
  gh api -X PUT "repos/${OWNER}/${repo}/environments/nonprod" >/dev/null
  echo "    ${repo} has a nonprod environment"
done

echo
echo "Done. Client id: $APP_ID"
