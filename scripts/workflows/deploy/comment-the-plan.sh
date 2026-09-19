#!/usr/bin/env bash
# Puts the plan on the pull request, and on the run summary.
#
# Only on a pull request: a manual run has no pull request to comment on. The
# plan is in the job log either way.
#
# A comment is capped at 65536 characters by the API, so a long plan is cut
# short rather than losing the comment altogether.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/workflows/lib.sh
source "${HERE}/lib.sh"

readonly RECAP_NAME="plan"
readonly PLAN_FILE="${PLAN_FILE:-plan.txt}"
readonly MAX_LENGTH=60000

main() {
    task "plan : report what terraform intends to do"

    if [[ ! -s "$PLAN_FILE" ]]; then
        report_failed "plan" "${PLAN_FILE} is missing or empty"
        recap "$RECAP_NAME"
        return
    fi

    local plan body
    plan=$(<"$PLAN_FILE")
    if [[ "${#plan}" -gt "$MAX_LENGTH" ]]; then
        body="${plan:0:$MAX_LENGTH}"$'\n\n... truncated, see the job log for the full plan.'
        report_changed "plan" "${#plan} characters, truncated to ${MAX_LENGTH}"
    else
        body="$plan"
        report_ok "plan" "${#plan} characters"
    fi

    summary "plan" "terraform" "ok" "$(grep -cE '^(  #|Plan:)' <<<"$plan" || true) lines of interest" <<EOSUMMARY
<details><summary>The plan</summary>

\`\`\`terraform
${body}
\`\`\`

</details>
EOSUMMARY

    if [[ -z "${PULL_REQUEST:-}" ]]; then
        report_skipped "pull request" "no pull request on this event, the plan is on the summary page"
        recap "$RECAP_NAME"
        return
    fi

    if gh pr comment "$PULL_REQUEST" --body "### Terraform plan

\`\`\`terraform
${body}
\`\`\`"; then
        report_changed "pull request" "plan posted on #${PULL_REQUEST}"
    else
        report_unreachable "api.github.com" "could not post the comment"
    fi

    recap "$RECAP_NAME"
}

main "$@"
