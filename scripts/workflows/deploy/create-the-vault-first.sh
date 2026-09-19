#!/usr/bin/env bash
# Creates the Key Vault on its own before the rest, on a cold start only.
#
# Terraform would otherwise create it with its firewall closed and fail on the
# first secret it writes, having already built everything else. A no-op once
# the vault exists.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="cold-start"
readonly RESOURCE_GROUP="${RESOURCE_GROUP:?set it in the workflow, so the group is visible there}"
readonly PROJECT="${PROJECT:?set it in the workflow, so the project is visible there}"

main() {
    task "azure : does the Key Vault already exist"

    local existing
    if ! existing=$(az keyvault list --resource-group "$RESOURCE_GROUP" \
            --query "[?tags.project=='${PROJECT}'].name | [0]" -o tsv); then
        report_unreachable "azure" "az keyvault list did not answer"
        recap "$RECAP_NAME"
        return
    fi

    if [[ -n "$existing" ]]; then
        report_ok "$existing" "already exists, nothing to do first"
        recap "$RECAP_NAME"
        return
    fi

    task "terraform : create the Key Vault before the rest"
    if ! terraform apply -target=azurerm_key_vault.main \
            -input=false -auto-approve -lock-timeout=120s >&2; then
        report_failed "vault" "the targeted apply failed"
        recap "$RECAP_NAME"
        return
    fi
    report_changed "vault" "created ahead of the full apply"

    "${HERE}/deploy/keyvault-firewall.sh" add
    report_changed "vault" "firewall opened to this runner"

    recap "$RECAP_NAME"
}

main "$@"
