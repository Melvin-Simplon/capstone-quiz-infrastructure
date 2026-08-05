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
REPO="WhiteMuush/simplon-quiz-infrastructure-bilan"
SUBSCRIPTION_ID="5e683e0f-b00c-48d6-9769-5aaf598de8f1"
RESOURCE_GROUP="mpetitRG"
SHARED_RESOURCE_GROUP="rg-shared-prf2026"
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
# One subject per trusted context. Anything else, another branch or another
# repository, gets no token at all.
add_federated_credential() {
  local name="$1" subject="$2"
  az ad app federated-credential list --id "$APP_ID" --query "[?name=='$name']" -o tsv | grep -q . && {
    echo "    $name already there"
    return
  }
  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"$name\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"$subject\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" >/dev/null
  echo "    $name created"
}

add_federated_credential "main-branch" "repo:${REPO}:ref:refs/heads/main"
add_federated_credential "pull-request" "repo:${REPO}:pull_request"
add_federated_credential "nonprod-environment" "repo:${REPO}:environment:nonprod"

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

# The state account has shared key access disabled, so reaching the state needs
# a data plane role. Control plane rights alone would not open the blob.
assign "Storage Blob Data Contributor" \
  "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${STATE_ACCOUNT}"

# The shared App Service Plan is read as a data source. Reader is enough, and it
# makes it impossible to alter a resource the whole promotion depends on.
assign "Reader" "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${SHARED_RESOURCE_GROUP}"

echo "==> GitHub repository variables"
# Variables and not secrets: none of these three values is confidential, and
# masking them in the logs only makes failures harder to read.
TENANT_ID=$(az account show --query tenantId -o tsv)
gh variable set AZURE_CLIENT_ID --repo "$REPO" --body "$APP_ID"
gh variable set AZURE_TENANT_ID --repo "$REPO" --body "$TENANT_ID"
gh variable set AZURE_SUBSCRIPTION_ID --repo "$REPO" --body "$SUBSCRIPTION_ID"

echo
echo "Done. Client id: $APP_ID"
