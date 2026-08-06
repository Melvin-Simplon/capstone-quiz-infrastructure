# 0008. Terraform may not delete what holds data

Accepted, 2026-08-06.

## Context

tflint reads a configuration the way an auditor would, and asked for `prevent_destroy` on every
resource carrying state: the database server and its database, the storage account and its
container, the vault and its secrets.

## Decision

Applied to all seven.

## Consequences

No plan can propose to drop them, including by replacement, which is the failure mode that matters:
a changed argument silently forcing a recreate is how data disappears without anyone deciding to
delete it.

The cost is real and belongs here rather than in a surprise: tearing this environment down now
starts by removing those blocks, deliberately, in a commit of its own. `prevent_destroy` takes a
literal, so no variable can soften it.
