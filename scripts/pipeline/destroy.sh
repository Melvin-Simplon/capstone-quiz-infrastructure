#!/usr/bin/env bash

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/pipeline/lib.sh
source "${HERE}/lib.sh"

REPO=''
WORKFLOW=''
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)     REPO="${2:-}"; shift 2 ;;
        --workflow) WORKFLOW="${2:-}"; shift 2 ;;
        *)          die "unknown argument: $1" ;;
    esac
done
[[ -n "${REPO}" && -n "${WORKFLOW}" ]] || die "usage: destroy.sh --repo OWNER/NAME --workflow FILE"

cat >&2 <<EOF

This destroys every resource in ${RESOURCE_GROUP}, the database included.
ADR 0012 removed the prevent_destroy blocks, so nothing will stop it.
The state on Terraform Cloud survives, the data does not.

EOF

read -r -p "Type the resource group name to confirm: " answer
if [[ "${answer}" != "${RESOURCE_GROUP}" ]]; then
    die "got '${answer}', expected '${RESOURCE_GROUP}'. Nothing was touched."
fi

exec "${HERE}/dispatch.sh" \
    --repo "${REPO}" \
    --workflow "${WORKFLOW}" \
    --label "destroy" \
    --field "confirm=${RESOURCE_GROUP}"
