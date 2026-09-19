#!/usr/bin/env bash
# Formatting and validity of the Terraform configuration.
#
# init -backend=false skips the cloud block, so this needs no HCP Terraform
# token and no Azure credential.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="terraform"

check_formatting() {
    task "terraform : every file is formatted"
    local unformatted
    if unformatted=$(terraform fmt -check -recursive 2>&1); then
        report_ok "configuration" "all files formatted"
        return 0
    fi
    report_failed "configuration" "not formatted, run terraform fmt -recursive"
    printf '%s\n' "$unformatted" >&2
    return 1
}

check_validity() {
    task "terraform : the configuration is valid"
    if ! terraform init -backend=false -input=false >&2; then
        report_failed "configuration" "terraform init failed"
        return 1
    fi
    if terraform validate >&2; then
        report_ok "configuration" "valid"
        return 0
    fi
    report_failed "configuration" "terraform validate found errors"
    return 1
}

main() {
    check_formatting || true
    check_validity || true
    recap "$RECAP_NAME"
}

main "$@"
