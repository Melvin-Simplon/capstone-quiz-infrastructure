#!/usr/bin/env bash
# Triggers one workflow and follows its run until it ends.
#
# The single place that knows how to do this. Every deployment target calls it
# with different arguments rather than repeating the dispatch and the wait, so
# the way a run is followed changes here and nowhere else.

set -euo pipefail

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

# The id of the newest run before dispatching, so the one that appears after can
# be told apart. `gh workflow run` returns nothing identifying the run it just
# created, which is the whole difficulty here.
latest_run_id() {
    gh run list --repo "${REPO}" --workflow "${WORKFLOW}" \
        --limit 1 --json databaseId --jq '.[0].databaseId // 0' 2>/dev/null || echo 0
}

before=$(latest_run_id)

log_info "${LABEL}: dispatching ${WORKFLOW} on ${REPO} (${REF})"
if ! gh workflow run "${WORKFLOW}" --repo "${REPO}" --ref "${REF}" "${FIELDS[@]+"${FIELDS[@]}"}"; then
    die "${LABEL}: the dispatch was refused. Does ${WORKFLOW} declare workflow_dispatch on ${REF}?"
fi

# GitHub registers the run a moment after accepting the dispatch, so the id is
# not available immediately.
run_id=0
for _ in $(seq 1 30); do
    sleep 2
    run_id=$(latest_run_id)
    [[ "${run_id}" != "${before}" && "${run_id}" != "0" ]] && break
    run_id=0
done

if [[ "${run_id}" == "0" ]]; then
    die "${LABEL}: dispatched, but no new run appeared after a minute. Check ${REPO} on GitHub."
fi

url=$(gh run view "${run_id}" --repo "${REPO}" --json url --jq .url 2>/dev/null || echo '')
log_info "${LABEL}: run ${run_id} started"
[[ -n "${url}" ]] && log_hint "${url}"

# --exit-status makes a failed run fail this script, which stops the chain in
# `make deploy` instead of moving on to a component that cannot work.
if gh run watch "${run_id}" --repo "${REPO}" --exit-status >/dev/null 2>&1; then
    log_ok "${LABEL}: succeeded"
    if [[ "${PRINT_LOG}" -eq 1 ]]; then
        gh run view "${run_id}" --repo "${REPO}" --log 2>/dev/null || true
    fi
    exit 0
fi

log_fail "${LABEL}: the run failed"
[[ -n "${url}" ]] && log_hint "${url}"
# The failing job's log is not printed here on purpose: it is long, and the URL
# above opens the part that matters without burying the rest of the output.
exit 1
