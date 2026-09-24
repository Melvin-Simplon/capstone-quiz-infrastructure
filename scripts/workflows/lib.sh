#!/usr/bin/env bash

if [[ -t 2 || -n "${GITHUB_ACTIONS:-}" ]] && [[ -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\033[0m'
    C_OK=$'\033[0;32m'
    C_CHANGED=$'\033[0;33m'
    C_SKIPPED=$'\033[0;36m'
    C_FAILED=$'\033[0;31m'
    C_UNREACHABLE=$'\033[1;31m'
    C_HEAD=$'\033[1m'
else
    C_RESET=''; C_OK=''; C_CHANGED=''; C_SKIPPED=''
    C_FAILED=''; C_UNREACHABLE=''; C_HEAD=''
fi

RECAP_OK=0
RECAP_CHANGED=0
RECAP_UNREACHABLE=0
RECAP_FAILED=0
RECAP_SKIPPED=0

_stars() { printf '*%.0s' $(seq 1 "$1"); }

task() {
    local title="TASK [$1] " pad
    pad=$(( 72 - ${#title} ))
    [[ "$pad" -lt 3 ]] && pad=3
    printf '\n%s%s%s%s\n' "$C_HEAD" "$title" "$(_stars "$pad")" "$C_RESET" >&2
}

_report() {
    local colour="$1" label="$2" host="$3"; shift 3
    printf '%s%-12s%s [%s] %s\n' "$colour" "${label}:" "$C_RESET" "$host" "$*" >&2
}

report_ok()          { RECAP_OK=$(( RECAP_OK + 1 ));                   _report "$C_OK"          ok          "$@"; }
report_changed()     { RECAP_CHANGED=$(( RECAP_CHANGED + 1 ));         _report "$C_CHANGED"     changed     "$@"; }
report_skipped()     { RECAP_SKIPPED=$(( RECAP_SKIPPED + 1 ));         _report "$C_SKIPPED"     skipping    "$@"; }
report_failed()      { RECAP_FAILED=$(( RECAP_FAILED + 1 ));           _report "$C_FAILED"      fatal       "$@"; }
report_unreachable() { RECAP_UNREACHABLE=$(( RECAP_UNREACHABLE + 1 )); _report "$C_UNREACHABLE" unreachable "$@"; }

hint() { printf '             %s\n' "$*" >&2; }

recap() {
    local name="${1:-play}"
    printf '\n%sPLAY RECAP %s%s\n' "$C_HEAD" "$(_stars 62)" "$C_RESET" >&2
    printf '%-22s : %sok=%-3d%s %schanged=%-3d%s %sunreachable=%-3d%s %sfailed=%-3d%s %sskipped=%-3d%s\n' \
        "$name" \
        "$C_OK" "$RECAP_OK" "$C_RESET" \
        "$C_CHANGED" "$RECAP_CHANGED" "$C_RESET" \
        "$C_UNREACHABLE" "$RECAP_UNREACHABLE" "$C_RESET" \
        "$C_FAILED" "$RECAP_FAILED" "$C_RESET" \
        "$C_SKIPPED" "$RECAP_SKIPPED" "$C_RESET" >&2
    [[ "$RECAP_FAILED" -eq 0 && "$RECAP_UNREACHABLE" -eq 0 ]]
}

summary() {
    local category="$1" tool="$2" status="$3" figures="$4"
    [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] || return 0
    {
        printf '## %s : %s\n\n' "$category" "$tool"
        printf '**%s** : %s\n\n' "$status" "$figures"
        cat
    } >> "$GITHUB_STEP_SUMMARY"
}

die() {
    local host="$1"; shift
    report_failed "$host" "$@"
    recap "${RECAP_NAME:-play}" || true
    exit 1
}
