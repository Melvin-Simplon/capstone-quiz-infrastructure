#!/usr/bin/env bash
# Where each repository stands, and what is actually reachable on Azure.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/pipeline/lib.sh
source "${HERE}/lib.sh"

FOLLOW=0
[[ "${1:-}" == "--follow" ]] && FOLLOW=1

require_cmd gh "See https://cli.github.com"

REPOS=("${ORG}/${INFRA_REPO}" "${ORG}/${BACKEND_REPO}" "${ORG}/${FRONTEND_REPO}")

# Follows whatever is running right now, across the three repositories. The
# first one found wins: they are dispatched in sequence, so at most one is
# in flight when `make deploy` is driving them.
follow_running() {
    local repo id
    for repo in "${REPOS[@]}"; do
        id=$(gh run list --repo "${repo}" --status in_progress \
            --limit 1 --json databaseId --jq '.[0].databaseId // empty' 2>/dev/null || true)
        if [[ -n "${id}" ]]; then
            log_info "following ${repo} run ${id}"
            gh run watch "${id}" --repo "${repo}" --exit-status
            return $?
        fi
    done
    log_info "nothing is running"
}

show_runs() {
    log_info "Last run"
    local repo line
    for repo in "${REPOS[@]}"; do
        line=$(gh run list --repo "${repo}" --limit 1 \
            --json status,conclusion,displayTitle,createdAt \
            --jq '.[0] | "\(.status)/\(.conclusion // "-")  \(.createdAt[0:16])  \(.displayTitle)"' \
            2>/dev/null || true)
        printf '  %-34s %s\n' "${repo##*/}" "${line:-no run yet}" >&2
    done
}

# Resolved by tag rather than by name, the same way the pipelines find them, so
# a rebuilt environment is reported without editing anything here.
show_urls() {
    log_info "Deployed"

    have az || { log_warn "az absent, cannot resolve the URLs"; return; }
    az account show >/dev/null 2>&1 || { log_warn "no az session, cannot resolve the URLs"; return; }

    local tagged="[?tags.project=='simplon-quiz']"
    local backend site
    backend=$(az webapp list --query "${tagged} | [?tags.component=='backend'].defaultHostName | [0]" -o tsv 2>/dev/null || true)
    site=$(az staticwebapp list --query "${tagged} | [?tags.component=='frontend'].defaultHostname | [0]" -o tsv 2>/dev/null || true)

    printf '  %-34s %s\n' "backend" "${backend:+https://${backend}}" >&2
    printf '  %-34s %s\n' "frontend" "${site:+https://${site}}" >&2
    [[ -z "${backend}${site}" ]] && log_hint "nothing tagged project=simplon-quiz yet"
}

if [[ "${FOLLOW}" -eq 1 ]]; then
    follow_running
else
    show_runs
    show_urls
fi
