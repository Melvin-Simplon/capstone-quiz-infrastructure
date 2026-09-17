#!/usr/bin/env bash
# Reports every prerequisite the other targets depend on.
#
# The only target that keeps going after a problem: knowing all of what is
# missing in one pass is the point. Exit status is 0 when nothing failed, so it
# can gate the rest of a chain.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/pipeline/lib.sh
source "${HERE}/lib.sh"

REPOS=(
    "${ORG}/${INFRA_REPO}:terraform.yml"
    "${ORG}/${BACKEND_REPO}:ci-cd.yml"
    "${ORG}/${FRONTEND_REPO}:ci-cd.yml"
)

check_github() {
    log_info "GitHub"

    if ! have gh; then
        check_failed "gh is not installed"
        log_hint "https://cli.github.com, then: gh auth login"
        return
    fi

    if gh auth status >/dev/null 2>&1; then
        local who
        who=$(gh api user --jq .login 2>/dev/null || echo "unknown")
        check_ok "gh authenticated as ${who}"
    else
        check_failed "gh is not authenticated"
        log_hint "gh auth login"
        return
    fi

    local entry repo
    for entry in "${REPOS[@]}"; do
        repo="${entry%%:*}"
        if gh repo view "${repo}" --json name >/dev/null 2>&1; then
            check_ok "${repo} reachable"
        else
            check_failed "${repo} unreachable"
        fi
    done
}

# A workflow without workflow_dispatch cannot be triggered at all, which is what
# every deployment target here does.
check_dispatch() {
    log_info "Manual triggers"

    have gh || { check_skipped "no gh, cannot read the workflows"; return; }

    local entry repo workflow body
    for entry in "${REPOS[@]}"; do
        repo="${entry%%:*}"
        workflow="${entry##*:}"

        body=$(gh api "repos/${repo}/contents/.github/workflows/${workflow}" \
            --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || true)

        if [[ -z "${body}" ]]; then
            check_skipped "${repo} ${workflow} not readable"
            continue
        fi

        if grep -q 'workflow_dispatch' <<<"${body}"; then
            check_ok "${repo} ${workflow} can be triggered by hand"
        else
            check_failed "${repo} ${workflow} has no workflow_dispatch"
            log_hint "add it, and widen the 'if: github.event_name' guards with it"
        fi
    done
}

check_azure() {
    log_info "Azure"

    if ! have az; then
        check_skipped "az absent, identity checks and status URLs unavailable"
        log_hint "only bootstrap and status need it, deployments do not"
        return
    fi

    local account
    account=$(az account show --query name -o tsv 2>/dev/null || true)
    if [[ -z "${account}" ]]; then
        check_skipped "no az session"
        log_hint "az login"
        return
    fi
    check_ok "signed in on ${account}"

    if az group show --name "${RESOURCE_GROUP}" >/dev/null 2>&1; then
        local count
        count=$(az resource list -g "${RESOURCE_GROUP}" --query 'length(@)' -o tsv 2>/dev/null || echo 0)
        check_ok "resource group ${RESOURCE_GROUP} exists, ${count} resources"
    else
        check_failed "resource group ${RESOURCE_GROUP} not found"
    fi
}

# The failure this catches is invisible from GitHub: the credentials exist and
# look healthy, but they name an owner and a repository that GitHub no longer
# signs, so azure/login fails on every run with nothing pointing at why.
check_oidc() {
    log_info "OIDC trust"

    have az || { check_skipped "az absent, cannot read the federated credentials"; return; }
    have gh || { check_skipped "gh absent, cannot read what GitHub signs"; return; }
    az account show >/dev/null 2>&1 || { check_skipped "no az session"; return; }

    local app_id
    app_id=$(az ad app list --display-name "${OIDC_APP_NAME}" --query '[0].appId' -o tsv 2>/dev/null || true)
    if [[ -z "${app_id}" ]]; then
        check_failed "app registration ${OIDC_APP_NAME} not found"
        log_hint "make bootstrap"
        return
    fi
    check_ok "app registration ${app_id}"

    local subjects
    subjects=$(az ad app federated-credential list --id "${app_id}" --query '[].subject' -o tsv 2>/dev/null || true)

    local entry repo prefix
    for entry in "${REPOS[@]}"; do
        repo="${entry%%:*}"
        prefix=$(oidc_subject_prefix "${repo}")

        if grep -qF "${prefix}" <<<"${subjects}"; then
            check_ok "${repo} is trusted"
        else
            check_failed "${repo} has no credential matching what GitHub signs"
            log_hint "expected a subject starting with ${prefix}"
            log_hint "make bootstrap"
        fi
    done
}

check_terraform_cloud() {
    log_info "Terraform Cloud"

    local token
    token=$(hcp_token || true)
    if [[ -z "${token}" ]]; then
        check_failed "no HCP Terraform token"
        log_hint "terraform login"
        return
    fi

    local code
    code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 \
        -H "Authorization: Bearer ${token}" \
        https://app.terraform.io/api/v2/account/details 2>/dev/null || echo 000)

    if [[ "${code}" != "200" ]]; then
        check_failed "the HCP Terraform token is refused (http ${code})"
        log_hint "terraform login"
        return
    fi
    check_ok "HCP Terraform token valid"

    local body
    body=$(curl -sS --max-time 15 -H "Authorization: Bearer ${token}" \
        "https://app.terraform.io/api/v2/organizations/${TF_ORG}/workspaces/${TF_WORKSPACE}" \
        2>/dev/null || true)

    if grep -q '"id"' <<<"${body}" && ! grep -q '"status":"404"' <<<"${body}"; then
        # Remote execution would run Terraform on HashiCorp infrastructure, at an
        # address the Key Vault firewall script cannot open, and every plan
        # reading a secret would fail.
        if grep -q '"execution-mode":"local"' <<<"${body}"; then
            check_ok "workspace ${TF_WORKSPACE} exists, execution mode local"
        else
            check_failed "workspace ${TF_WORKSPACE} is not in local execution mode"
            log_hint "remote execution breaks the Key Vault firewall step"
        fi
    else
        check_failed "workspace ${TF_ORG}/${TF_WORKSPACE} does not exist"
        log_hint "make bootstrap"
    fi
}

main() {
    check_github
    check_dispatch
    check_azure
    check_oidc
    check_terraform_cloud
    recap
}

main "$@"
