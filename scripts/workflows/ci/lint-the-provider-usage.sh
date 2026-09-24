#!/usr/bin/env bash

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="tflint"
readonly ATTEMPTS=3

install_rulesets() {
    task "tflint : install the rulesets"
    local attempt
    for attempt in $(seq 1 "$ATTEMPTS"); do
        if tflint --init >&2; then
            report_ok "rulesets" "installed"
            return 0
        fi
        if [[ "$attempt" -eq "$ATTEMPTS" ]]; then
            report_unreachable "api.github.com" "tflint --init failed ${ATTEMPTS} times"
            hint "an unauthenticated runner shares a sixty per hour quota; check GITHUB_TOKEN reached this step"
            return 1
        fi
        printf 'tflint --init failed, retrying in %ss.\n' "$(( attempt * 10 ))" >&2
        sleep "$(( attempt * 10 ))"
    done
}

lint() {
    task "tflint : lint the provider usage"
    if tflint --format compact --recursive >&2; then
        report_ok "configuration" "no finding"
        return 0
    fi
    report_failed "configuration" "tflint found something, see the lines above"
    return 1
}

main() {
    local status=0
    install_rulesets || status=1
    [[ "$status" -eq 0 ]] && { lint || true; }
    recap "$RECAP_NAME"
}

main "$@"
