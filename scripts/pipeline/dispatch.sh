#!/usr/bin/env bash

set -euo pipefail

ORIGINAL_ARGS="$*"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/pipeline/lib.sh
source "${HERE}/lib.sh"

REPO=''
WORKFLOW=''
LABEL=''
REF='main'
PRINT_LOG=0
FIELDS=()

usage() {
    cat >&2 <<'EOF'
usage: dispatch.sh --repo OWNER/NAME --workflow FILE [options]

  --label NAME     name used in the messages, defaults to the workflow file
  --field K=V      input passed to the workflow, repeatable
  --ref REF        branch to run on, defaults to main
  --print-log      print the run log once it finishes
EOF
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)      REPO="${2:-}"; shift 2 ;;
        --workflow)  WORKFLOW="${2:-}"; shift 2 ;;
        --label)     LABEL="${2:-}"; shift 2 ;;
        --ref)       REF="${2:-}"; shift 2 ;;
        --field)     FIELDS+=(-f "${2:-}"); shift 2 ;;
        --print-log) PRINT_LOG=1; shift ;;
        -h|--help)   usage ;;
        *)           die "unknown argument: $1" ;;
    esac
done

[[ -n "${REPO}" ]] || usage
[[ -n "${WORKFLOW}" ]] || usage
[[ -n "${LABEL}" ]] || LABEL="${WORKFLOW}"

require_cmd gh "See https://cli.github.com"
gh auth status >/dev/null 2>&1 || die "gh is not authenticated. Run: gh auth login"

task "${LABEL} : dispatch ${WORKFLOW} on ${REPO}"

latest_run_id() {
    gh run list --repo "${REPO}" --workflow "${WORKFLOW}" \
        --limit 1 --json databaseId --jq '.[0].databaseId // 0' 2>/dev/null || echo 0
}

before=$(latest_run_id)

if ! gh workflow run "${WORKFLOW}" --repo "${REPO}" --ref "${REF}" "${FIELDS[@]+"${FIELDS[@]}"}" 2>/dev/null; then
    report_failed "${LABEL}" "the dispatch was refused"
    hint "does ${WORKFLOW} declare workflow_dispatch on ${REF}?"
    recap "${LABEL}"
    exit 1
fi

run_id=0
for _ in $(seq 1 30); do
    sleep 2
    run_id=$(latest_run_id)
    [[ "${run_id}" != "${before}" && "${run_id}" != "0" ]] && break
    run_id=0
done

if [[ "${run_id}" == "0" ]]; then
    report_unreachable "${LABEL}" "dispatched, but no new run appeared after a minute"
    hint "check https://github.com/${REPO}/actions"
    recap "${LABEL}"
    exit 1
fi

url=$(gh run view "${run_id}" --repo "${REPO}" --json url --jq .url 2>/dev/null || echo '')
hint "run ${run_id}${url:+ at ${url}}"

if gh run watch "${run_id}" --repo "${REPO}" --exit-status >/dev/null 2>&1; then
    report_changed "${LABEL}" "run ${run_id} succeeded"
    [[ "${PRINT_LOG}" -eq 1 ]] && { gh run view "${run_id}" --repo "${REPO}" --log 2>/dev/null || true; }
    recap "${LABEL}"
    exit 0
fi

report_failed "${LABEL}" "run ${run_id} failed"
[[ -n "${url}" ]] && hint "${url}"
recap "${LABEL}"
exit 1
