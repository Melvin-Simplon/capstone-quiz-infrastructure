#!/usr/bin/env bash
# Shared by the scripts in this directory. Sourced, never executed.
#
# Every diagnostic goes to stderr, without exception. Some of these scripts have
# their output captured by a caller, and a log written to stdout would come back
# glued to the value the caller asked for.

# Read by the scripts that source this file, not by this file itself.
# shellcheck disable=SC2034
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colour only when a human is looking at a terminal, and never against NO_COLOR.
# A CI log and a piped output both keep the escape sequences out.
if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\033[0m'; C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_DIM=$'\033[2m'
else
    C_RESET=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_DIM=''
fi

log_info() { printf '%s\n' "${C_BLUE}==>${C_RESET} $*" >&2; }
log_ok()   { printf '%s\n' "  ${C_GREEN}ok${C_RESET}      $*" >&2; }
log_warn() { printf '%s\n' "  ${C_YELLOW}skipped${C_RESET} $*" >&2; }
log_fail() { printf '%s\n' "  ${C_RED}failed${C_RESET}  $*" >&2; }
log_hint() { printf '%s\n' "          ${C_DIM}$*${C_RESET}" >&2; }

die() { printf '%s\n' "${C_RED}error${C_RESET} $*" >&2; exit 1; }

# Counters behind the RECAP line. "skipped" is deliberately distinct from
# "failed": something that could not be checked is not something that is broken,
# and merging the two produces false alarms.
CHECKS_OK=0
CHECKS_FAILED=0
CHECKS_SKIPPED=0

check_ok()      { CHECKS_OK=$((CHECKS_OK + 1)); log_ok "$*"; }
check_failed()  { CHECKS_FAILED=$((CHECKS_FAILED + 1)); log_fail "$*"; }
check_skipped() { CHECKS_SKIPPED=$((CHECKS_SKIPPED + 1)); log_warn "$*"; }

# Returns non-zero when anything failed, so the caller can use it as its exit
# status and a pipeline can branch on it.
recap() {
    printf '\n%s\n' "RECAP ____________________________________________" >&2
    printf '%s\n' "  ok=${CHECKS_OK}  failed=${CHECKS_FAILED}  skipped=${CHECKS_SKIPPED}" >&2
    [[ "${CHECKS_FAILED}" -eq 0 ]]
}

have() { command -v "$1" >/dev/null 2>&1; }

require_cmd() {
    have "$1" || die "$1 is not installed. $2"
}

# Reads the HCP Terraform token the way Terraform itself does, environment first.
# stdout carries the token and nothing else.
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
    creds = json.load(open('${file}'))['credentials']['app.terraform.io']['token']
except (KeyError, ValueError):
    sys.exit(1)
sys.stdout.write(creds)
" 2>/dev/null
}

# The prefix GitHub actually signs into the OIDC subject for a repository. It
# carries the numeric ids of the owner and of the repository, so it changes when
# a repository is transferred even though the repository is the same one.
# stdout carries the prefix and nothing else.
oidc_subject_prefix() {
    local repo="$1" prefix
    prefix=$(gh api "repos/${repo}/actions/oidc/customization/sub" \
        --jq '.sub_claim_prefix' 2>/dev/null || true)
    [[ -n "${prefix}" ]] && printf '%s' "${prefix}" || printf 'repo:%s' "${repo}"
}
