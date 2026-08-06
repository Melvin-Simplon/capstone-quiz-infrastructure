# 0010. Pipelines find their targets by tag, never by name

Accepted, 2026-08-06.

## Context

The deployment pipelines live in two other repositories and have to reach a web app, a static site
and a vault. Hardcoding names would tie three repositories together through strings nobody
validates.

## Decision

Every resource carries `project`, `owner`, `environment`, `managed_by` and a per-resource
`component` tag. Pipelines ask Azure for their target by tag.

## Consequences

Renaming a resource, or rebuilding this environment under different names, leaves the workflows
untouched. The tags stop being decoration and become the contract between the repositories.

The cost is an indirection: reading a workflow no longer tells you which resource it deploys to,
only how it will ask. Each lookup therefore fails loudly when a tag matches nothing, rather than
carrying an empty value forward.

That failure mode is not hypothetical. Asking `az` for two values at once returns a JSON array,
which `tsv` prints one element per line rather than as two columns, so a resource group name came
back empty and Azure reported it as an authorization failure over a nonsensical scope. Every lookup
is now one query per value, and every value is checked.
