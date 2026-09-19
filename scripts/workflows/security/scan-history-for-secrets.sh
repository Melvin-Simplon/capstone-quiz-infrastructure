#!/usr/bin/env bash
# Reads commits rather than files: something committed and removed the next day
# is still readable forever in a public repository. Needs a full clone, which
# the workflow asks for with fetch-depth: 0.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="secrets"
readonly GITLEAKS_VERSION="${GITLEAKS_VERSION:?set it in the workflow, so the version is visible there}"

install_gitleaks() {
    task "gitleaks ${GITLEAKS_VERSION} : install"
    local url="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"

    if ! curl -sSfL --proto '=https' --proto-redir '=https' "$url" | tar -xz gitleaks; then
        report_unreachable "github.com" "could not fetch gitleaks ${GITLEAKS_VERSION}"
        return 1
    fi
    report_changed "runner" "gitleaks ${GITLEAKS_VERSION} installed"
}

scan_history() {
    task "history : scan every commit for secrets"
    # --redact so a finding names the file and the commit without reprinting
    # the secret into a public log.
    if ./gitleaks git . --no-banner --redact; then
        report_ok "history" "no secret found"
    else
        report_failed "history" "gitleaks found something, see the lines above"
        return 1
    fi
}

main() {
    local status=0
    install_gitleaks || status=1
    [[ "$status" -eq 0 ]] && { scan_history || status=1; }
    recap "$RECAP_NAME"
}

main "$@"
