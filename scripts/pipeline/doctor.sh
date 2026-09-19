#!/usr/bin/env bash
# Reports every prerequisite the other targets depend on.
#
# The only script here that keeps going after a problem: knowing all of what is
# missing in one pass is the point. Read only, so nothing is ever reported as
# changed. Exit status is 0 when nothing failed and nothing was unreachable.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/pipeline/lib.sh
source "${HERE}/lib.sh"

# Each entry names the workflow the matching make target dispatches, so this
# check fails the day one is renamed rather than the next deployment.
REPOS=(
    "${ORG}/${INFRA_REPO}:terraform.yml"
    "${ORG}/${BACKEND_REPO}:ci-cd.yml"
    "${ORG}/${FRONTEND_REPO}:cd.yml"
)

check_github() {
    task "github : authentication and repositories"

    if ! have gh; then
        report_failed "workstation" "gh is not installed"
        hint "https://cli.github.com, then: gh auth login"
        return
    fi

    if ! gh auth status >/dev/null 2>&1; then
        report_failed "workstation" "gh is not authenticated"
        hint "gh auth login"
        return
    fi

    local who
    who=$(gh api user --jq .login 2>/dev/null || echo unknown)
    report_ok "workstation" "gh authenticated as ${who}"

    local entry repo
    for entry in "${REPOS[@]}"; do
        repo="${entry%%:*}"
        if gh repo view "${repo}" --json name >/dev/null 2>&1; then
            report_ok "${repo##*/}" "reachable"
        else
            report_unreachable "${repo##*/}" "cannot be read"
        fi
    done
}

# A workflow without workflow_dispatch cannot be triggered at all, which is what
# every deployment target here does.
check_dispatch() {
    task "github : workflows can be triggered by hand"

    have gh || { report_skipped "workstation" "no gh, cannot read the workflows"; return; }

    local entry repo workflow body
    for entry in "${REPOS[@]}"; do
        repo="${entry%%:*}"
        workflow="${entry##*:}"

        body=$(gh api "repos/${repo}/contents/.github/workflows/${workflow}" \
            --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || true)

        if [[ -z "${body}" ]]; then
            report_unreachable "${repo##*/}" "${workflow} could not be read"
        elif grep -q 'workflow_dispatch' <<<"${body}"; then
            report_ok "${repo##*/}" "${workflow} declares workflow_dispatch"
        else
            report_failed "${repo##*/}" "${workflow} has no workflow_dispatch"
            hint "add it, and widen the 'if: github.event_name' guards with it"
        fi
    done
}

check_azure() {
    task "azure : session and resource group"

    if ! have az; then
        report_skipped "workstation" "az absent, identity checks and status URLs unavailable"
        hint "only bootstrap and status need it, deployments do not"
        return
    fi

    local account
    account=$(az account show --query name -o tsv 2>/dev/null || true)
    if [[ -z "${account}" ]]; then
        report_skipped "workstation" "no az session"
        hint "az login"
        return
    fi
    report_ok "workstation" "signed in on ${account}"

    if az group show --name "${RESOURCE_GROUP}" >/dev/null 2>&1; then
        local count
        count=$(az resource list -g "${RESOURCE_GROUP}" --query 'length(@)' -o tsv 2>/dev/null || echo 0)
        report_ok "${RESOURCE_GROUP}" "exists, ${count} resources"
    else
        report_failed "${RESOURCE_GROUP}" "resource group not found"
    fi
}

# The failure this catches is invisible from GitHub: the credentials exist and
# look healthy, but they name an owner and a repository that GitHub no longer
# signs, so azure/login fails on every run with nothing pointing at why.
check_oidc() {
    task "azure : the OIDC trust matches what github signs"

    have az || { report_skipped "workstation" "az absent"; return; }
    have gh || { report_skipped "workstation" "gh absent"; return; }
    az account show >/dev/null 2>&1 || { report_skipped "workstation" "no az session"; return; }

    local app_id
    app_id=$(az ad app list --display-name "${OIDC_APP_NAME}" --query '[0].appId' -o tsv 2>/dev/null || true)
    if [[ -z "${app_id}" ]]; then
        report_failed "${OIDC_APP_NAME}" "app registration not found"
        hint "make bootstrap"
        return
    fi
    report_ok "${OIDC_APP_NAME}" "app registration ${app_id}"

    local subjects
    subjects=$(az ad app federated-credential list --id "${app_id}" --query '[].subject' -o tsv 2>/dev/null || true)

    local entry repo prefix
    for entry in "${REPOS[@]}"; do
        repo="${entry%%:*}"
        prefix=$(oidc_subject_prefix "${repo}")

        if grep -qF "${prefix}" <<<"${subjects}"; then
            report_ok "${repo##*/}" "trusted"
        else
            report_failed "${repo##*/}" "no federated credential matches what GitHub signs"
            hint "expected a subject starting with ${prefix}"
            hint "make bootstrap"
        fi
    done
}

check_terraform_cloud() {
    task "terraform cloud : token and workspace"

    local token
    token=$(hcp_token || true)
    if [[ -z "${token}" ]]; then
        report_failed "app.terraform.io" "no token"
        hint "terraform login"
        return
    fi

    local code
    code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 \
        -H "Authorization: Bearer ${token}" \
        https://app.terraform.io/api/v2/account/details 2>/dev/null || echo 000)

    case "${code}" in
        200) report_ok "app.terraform.io" "token valid" ;;
        000) report_unreachable "app.terraform.io" "no answer from the API"; return ;;
        *)   report_failed "app.terraform.io" "token refused (http ${code})"
             hint "terraform login"
             return ;;
    esac

    local body
    body=$(curl -sS --max-time 15 -H "Authorization: Bearer ${token}" \
        "https://app.terraform.io/api/v2/organizations/${TF_ORG}/workspaces/${TF_WORKSPACE}" \
        2>/dev/null || true)

    if [[ -z "${body}" ]]; then
        report_unreachable "${TF_WORKSPACE}" "no answer when reading the workspace"
    elif grep -q '"status":"404"' <<<"${body}" || ! grep -q '"id"' <<<"${body}"; then
        report_failed "${TF_WORKSPACE}" "workspace does not exist in ${TF_ORG}"
        hint "make bootstrap"
    elif grep -q '"execution-mode":"local"' <<<"${body}"; then
        report_ok "${TF_WORKSPACE}" "exists, execution mode local"
    else
        # Remote execution would run Terraform on HashiCorp infrastructure, at an
        # address the Key Vault firewall step cannot open, and every plan reading
        # a secret would fail.
        report_failed "${TF_WORKSPACE}" "execution mode is not local"
        hint "remote execution breaks the Key Vault firewall step"
    fi
}

main() {
    check_github
    check_dispatch
    check_azure
    check_oidc
    check_terraform_cloud
    recap "doctor"
}

main "$@"
