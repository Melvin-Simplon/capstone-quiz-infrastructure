#!/usr/bin/env bash
# Opens or closes the Key Vault firewall for the address this machine calls from.
#
# Terraform reads the vault's secrets over the data plane, which the firewall
# filters, so it needs to be let in. That address is not part of the desired
# state: a runner gets a new one on every run, and holding the list in the
# configuration deadlocks the refresh, since Terraform would have to read the
# secrets before it could grant itself the right to read them.
#
# The vault is found by tag rather than by name, so nothing here has to be kept
# in step with the Terraform configuration.

set -euo pipefail

action="${1:?usage: keyvault-firewall.sh add|remove}"
resource_group="${RESOURCE_GROUP:-mpetitRG}"
project="${PROJECT:-simplon-quiz}"

vault=$(az keyvault list --resource-group "$resource_group" \
  --query "[?tags.project=='${project}'].name | [0]" -o tsv)

if [ -z "$vault" ]; then
  echo "No vault tagged ${project} in ${resource_group} yet, nothing to do."
  exit 0
fi

ip=$(curl -fsS https://api.ipify.org)

case "$action" in
add)
  az keyvault network-rule add --name "$vault" --ip-address "${ip}/32" --only-show-errors >/dev/null
  # The rule is not in force the moment the call returns.
  sleep 15
  echo "${vault} opened to ${ip}"
  ;;
remove)
  az keyvault network-rule remove --name "$vault" --ip-address "${ip}/32" --only-show-errors >/dev/null
  echo "${vault} closed to ${ip}"
  ;;
*)
  echo "usage: keyvault-firewall.sh add|remove" >&2
  exit 1
  ;;
esac
