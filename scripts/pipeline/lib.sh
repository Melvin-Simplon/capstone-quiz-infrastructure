#!/usr/bin/env bash

# shellcheck disable=SC2034
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

LOG_FILE="${LOG_FILE:-${PROJECT_ROOT}/.logs/pipeline.log}"
LOG_SCOPE="$(basename "${0:-shell}" .sh)"

log_init() {
    local dir; dir="$(dirname "${LOG_FILE}")"
    mkdir -p "${dir}" 2>/dev/null || return 0
    touch "${LOG_FILE}" 2>/dev/null || return 0
    chmod 600 "${LOG_FILE}" 2>/dev/null || true
    printf '\n===== %s  %s  pid=%d  args=%s =====\n' \
        "$(date -Is)" "${LOG_SCOPE}" "$$" "${ORIGINAL_ARGS:-}" >>"${LOG_FILE}"
}

log_write() {
    [[ -w "${LOG_FILE}" ]] || return 0
    printf '%s  %-11s %s\n' "$(date -Is)" "${LOG_SCOPE}" "$*" \
        | sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g' >>"${LOG_FILE}"
}

if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\033[0m'
    C_OK=$'\033[0;32m'
    C_CHANGED=$'\033[0;33m'
    C_SKIPPED=$'\033[0;36m'
    C_FAILED=$'\033[0;31m'
    C_UNREACHABLE=$'\033[1;31m'
    C_HEAD=$'\033[1m'
    C_DIM=$'\033[2m'
else
    C_RESET=''; C_OK=''; C_CHANGED=''; C_SKIPPED=''
    C_FAILED=''; C_UNREACHABLE=''; C_HEAD=''; C_DIM=''
fi

RECAP_OK=0
RECAP_CHANGED=0
RECAP_UNREACHABLE=0
RECAP_FAILED=0
RECAP_SKIPPED=0

_stars() { printf '*%.0s' $(seq 1 "$1"); }

task() {
    local title="TASK [$1] " pad
    pad=$((79 - ${#title}))
    [[ "${pad}" -lt 3 ]] && pad=3
    printf '\n%s%s%s%s\n' "${C_HEAD}" "${title}" "$(_stars "${pad}")" "${C_RESET}" >&2
    log_write "TASK [$1]"
}

_report() {
    local colour="$1" label="$2" host="$3"; shift 3
    printf '%s%-12s%s [%s] %s\n' "${colour}" "${label}:" "${C_RESET}" "${host}" "$*" >&2
    log_write "$(printf '%-11s [%s] %s' "${label}:" "${host}" "$*")"
}

report_ok()          { RECAP_OK=$((RECAP_OK + 1));                   _report "${C_OK}"          "ok"          "$@"; }
report_changed()     { RECAP_CHANGED=$((RECAP_CHANGED + 1));         _report "${C_CHANGED}"     "changed"     "$@"; }
report_skipped()     { RECAP_SKIPPED=$((RECAP_SKIPPED + 1));         _report "${C_SKIPPED}"     "skipping"    "$@"; }
report_failed()      { RECAP_FAILED=$((RECAP_FAILED + 1));           _report "${C_FAILED}"      "fatal"       "$@"; }
report_unreachable() { RECAP_UNREACHABLE=$((RECAP_UNREACHABLE + 1)); _report "${C_UNREACHABLE}" "unreachable" "$@"; }

hint() { printf '%s             %s%s\n' "${C_DIM}" "$*" "${C_RESET}" >&2; log_write "             $*"; }

log_info() { printf '\n%s%s%s\n' "${C_HEAD}" "$*" "${C_RESET}" >&2; log_write "$*"; }
die() { printf '%sfatal:%s %s\n' "${C_FAILED}" "${C_RESET}" "$*" >&2; log_write "fatal: $*"; exit 1; }

recap() {
    local name="${1:-play}"
    printf '\n%sPLAY RECAP %s%s\n' "${C_HEAD}" "$(_stars 67)" "${C_RESET}" >&2
    printf '%-24s : %sok=%-3d%s %schanged=%-3d%s %sunreachable=%-3d%s %sfailed=%-3d%s %sskipped=%-3d%s\n' \
        "${name}" \
        "${C_OK}" "${RECAP_OK}" "${C_RESET}" \
        "${C_CHANGED}" "${RECAP_CHANGED}" "${C_RESET}" \
        "${C_UNREACHABLE}" "${RECAP_UNREACHABLE}" "${C_RESET}" \
        "${C_FAILED}" "${RECAP_FAILED}" "${C_RESET}" \
        "${C_SKIPPED}" "${RECAP_SKIPPED}" "${C_RESET}" >&2
    log_write "$(printf 'RECAP %-20s ok=%d changed=%d unreachable=%d failed=%d skipped=%d' \
        "${name}" "${RECAP_OK}" "${RECAP_CHANGED}" "${RECAP_UNREACHABLE}" "${RECAP_FAILED}" "${RECAP_SKIPPED}")"
    [[ "${RECAP_FAILED}" -eq 0 && "${RECAP_UNREACHABLE}" -eq 0 ]]
}

have() { command -v "$1" >/dev/null 2>&1; }

require_cmd() {
    have "$1" || die "$1 is not installed. $2"
}

hcp_token() {
    if [[ -n "${TF_TOKEN_app_terraform_io:-}" ]]; then
        printf '%s' "${TF_TOKEN_app_terraform_io}"
        return 0
    fi
    local file="${HOME}/.terraform.d/credentials.tfrc.json"
    [[ -r "${file}" ]] || return 1
    python3 -c "
import json, sys
try:
    token = json.load(open('${file}'))['credentials']['app.terraform.io']['token']
except (KeyError, ValueError):
    sys.exit(1)
sys.stdout.write(token)
" 2>/dev/null
}

oidc_subject_prefix() {
    local repo="$1" prefix
    prefix=$(gh api "repos/${repo}/actions/oidc/customization/sub" \
        --jq '.sub_claim_prefix' 2>/dev/null || true)
    [[ -n "${prefix}" ]] && printf '%s' "${prefix}" || printf 'repo:%s' "${repo}"
}

log_init
