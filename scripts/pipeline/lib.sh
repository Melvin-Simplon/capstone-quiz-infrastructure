#!/usr/bin/env bash
# Shared by the scripts in this directory. Sourced, never executed.
#
# The reporting contract is Ansible's, because it already answers the questions
# an operator actually asks: what ran, what changed, what could not be reached,
# and can this be run again safely.
#
# Five outcomes, and the distinctions between them are the point:
#
#   ok           already in the wanted state, nothing was done
#   changed      it was not, and this run changed it
#   skipped      it did not apply, or could not be evaluated here
#   unreachable  the thing itself could not be contacted
#   failed       it was contacted, evaluated, and it is wrong
#
# `changed` is what makes idempotence visible: a second run reporting changed=0
# is the proof of it, where a comment claiming idempotence is only an intention.
# `unreachable` keeps a network problem from being reported as a broken
# configuration, which is the false alarm that makes people stop reading output.
#
# Every diagnostic goes to stderr, without exception. Some of these scripts have
# their output captured by a caller, and a log written to stdout would come back
# glued to the value the caller asked for.

# Read by the scripts that source this file, not by this file itself.
# shellcheck disable=SC2034
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Every run appends to a log file. Written to directly rather than through a
# tee and a process substitution: that pattern loses its tail when the shell
# exits before the writer drains, and the end of a log is exactly the part
# someone opens it for.
#
# The file carries the plain text, never the escape sequences: the terminal
# keeps its colours, the file stays greppable and safe to paste into a ticket.
# Nothing here ever logs a token, and the two scripts that read one keep it in
# a variable that never reaches these functions.
LOG_FILE="${LOG_FILE:-${PROJECT_ROOT}/.logs/pipeline.log}"
LOG_SCOPE="$(basename "${0:-shell}" .sh)"

log_init() {
    local dir; dir="$(dirname "${LOG_FILE}")"
    mkdir -p "${dir}" 2>/dev/null || return 0
    # Append. Truncating would throw away the history, and with it the previous
    # attempt that explains why this one is being run.
    touch "${LOG_FILE}" 2>/dev/null || return 0
    # An operations journal has no business being world readable.
    chmod 600 "${LOG_FILE}" 2>/dev/null || true
    printf '\n===== %s  %s  pid=%d  args=%s =====\n' \
        "$(date -Is)" "${LOG_SCOPE}" "$$" "${ORIGINAL_ARGS:-}" >>"${LOG_FILE}"
}

# Timestamped per line, because a log is read to line up with something that
# happened at a known time.
log_write() {
    [[ -w "${LOG_FILE}" ]] || return 0
    printf '%s  %-11s %s\n' "$(date -Is)" "${LOG_SCOPE}" "$*" \
        | sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g' >>"${LOG_FILE}"
}

# Ansible's palette, for the same reason as its vocabulary: an operator already
# knows what yellow means. Colour only when a human is looking at a terminal,
# and never against NO_COLOR.
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

# TASK [name] ***********************************************************
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

# Indented under the line it explains, the way Ansible prints a task's detail.
hint() { printf '%s             %s%s\n' "${C_DIM}" "$*" "${C_RESET}" >&2; log_write "             $*"; }

log_info() { printf '\n%s%s%s\n' "${C_HEAD}" "$*" "${C_RESET}" >&2; log_write "$*"; }
die() { printf '%sfatal:%s %s\n' "${C_FAILED}" "${C_RESET}" "$*" >&2; log_write "fatal: $*"; exit 1; }

# Returns non-zero when anything failed or was unreachable, so a caller can use
# it as its exit status. Skipped never fails a run: not applicable is not wrong.
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

# Reads the HCP Terraform token the way Terraform itself does, environment
# first. stdout carries the token and nothing else.
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

log_init
