#!/usr/bin/env bash

set -euo pipefail

ORIGINAL_ARGS="$*"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/pipeline/lib.sh
source "${HERE}/lib.sh"

FOLLOW=0
[[ "${1:-}" == "--follow" ]] && FOLLOW=1

require_cmd gh "See https://cli.github.com"

REPOS=("${ORG}/${INFRA_REPO}" "${ORG}/${BACKEND_REPO}" "${ORG}/${FRONTEND_REPO}")

follow_running() {
    task "follow the run in progress"
    local repo id
    for repo in "${REPOS[@]}"; do
        id=$(gh run list --repo "${repo}" --status in_progress \
            --limit 1 --json databaseId --jq '.[0].databaseId // empty' 2>/dev/null || true)
        if [[ -n "${id}" ]]; then
            hint "${repo} run ${id}"
            if gh run watch "${id}" --repo "${repo}" --exit-status; then
                report_changed "${repo##*/}" "run ${id} succeeded"
            else
                report_failed "${repo##*/}" "run ${id} failed"
            fi
            recap "logs"
            return
        fi
    done
    report_skipped "workstation" "nothing is running"
    recap "logs"
}

show_runs() {
    task "github : last run of each repository"
    local repo line
    for repo in "${REPOS[@]}"; do
        line=$(gh run list --repo "${repo}" --limit 1 \
            --json status,conclusion,displayTitle,createdAt \
            --jq '.[0] | "\(.status)/\(.conclusion // "-")  \(.createdAt[0:16])  \(.displayTitle)"' \
            2>/dev/null || true)
        if [[ -z "${line}" ]]; then
            report_skipped "${repo##*/}" "no run yet"
        else
            report_ok "${repo##*/}" "${line}"
        fi
    done
}

show_urls() {
    task "azure : what answers today"

    have az || { report_skipped "workstation" "az absent, cannot resolve the URLs"; return; }
    az account show >/dev/null 2>&1 || { report_skipped "workstation" "no az session"; return; }

    local tagged="[?tags.project=='simplon-quiz']"
    local backend site
    backend=$(az webapp list --query "${tagged} | [?tags.component=='backend'].defaultHostName | [0]" -o tsv 2>/dev/null || true)
    site=$(az staticwebapp list --query "${tagged} | [?tags.component=='frontend'].defaultHostname | [0]" -o tsv 2>/dev/null || true)

    if [[ -n "${backend}" ]]; then
        report_ok "backend" "https://${backend}"
    else
        report_skipped "backend" "nothing tagged component=backend"
    fi

    if [[ -n "${site}" ]]; then
        report_ok "frontend" "https://${site}"
    else
        report_skipped "frontend" "nothing tagged component=frontend"
    fi
}

if [[ "${FOLLOW}" -eq 1 ]]; then
    follow_running
else
    show_runs
    show_urls
    recap "status"
fi
