# 0014. The vault takes a new name on every build

Accepted, 2026-09-24.

## Context

[0012](0012-the-environment-must-be-reproducible.md) made the environment something that is torn
down and rebuilt at will. The Key Vault does not go along with that on its own.

A deleted vault is not gone. Soft delete keeps it, secrets included, for
`soft_delete_retention_days`, which is set to seven, the lowest Azure accepts. For those seven days
its name stays taken. When Terraform then creates a vault with that name, the azurerm provider does
not fail: by default it recovers the deleted one, and the old secrets come back with it. The state
does not know them, and `azurerm_key_vault_secret` refuses to write over a secret it does not
manage.

That is how the rebuild of 2026-09-24 failed. The vault had been deleted on 2026-09-18, six days
earlier. The apply recovered it, built everything else, then stopped on the three secrets, which
still carried the versions written on 2026-09-17.

A purge would free the name, but it takes `Microsoft.KeyVault/locations/deletedVaults/purge/action`
at subscription scope. The pipeline identity holds Contributor on the resource group, and the owner
of this environment Reader on the subscription. Neither can purge, and the training subscription is
not ours to change.

## Decision

The vault name ends with four characters drawn by a `random_string`. Destroy removes that resource
with the rest, so every build draws a new one, and a new vault never meets a deleted one.

The name drops its dashes to stay within the 24 characters Azure allows, the way the storage account
name already does. A precondition fails the plan, with the reason, if `owner` and `project` ever make
it longer.

The provider is told to neither recover nor purge vaults, and not to purge secrets. Recovering is
what brought the old secrets back. Purging is a right nobody here holds, so destroy no longer asks for
it.

## Consequences

Every rebuild leaves the previous vault behind in soft delete for seven days, holding secrets that
are no longer used anywhere. Azure removes it at the end of the retention.

Nothing looks for the vault by name, [0010](0010-tag-based-discovery.md) already made every
pipeline find it by tag, so nothing else had to change. A person looking for it reads the
`key_vault_name` output, or filters the portal on the tags.

The fresh name depends on the state being destroyed too. Deleting the resources from the portal
leaves the drawn suffix in the state, and the next apply would ask for the same name again. It now
fails with the vault reported as soft deleted rather than recovering it, and running the destroy
workflow afterwards clears the state as it did on 2026-09-18.

An environment built before this change cannot be migrated in place. The new name forces a new vault,
created with its firewall closed in the middle of the apply, and the first secret written to it would
be refused. It has to be destroyed and built again, which [0012](0012-the-environment-must-be-reproducible.md)
already made the normal way to change it.
