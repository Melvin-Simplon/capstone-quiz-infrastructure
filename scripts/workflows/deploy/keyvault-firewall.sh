#!/usr/bin/env bash

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
