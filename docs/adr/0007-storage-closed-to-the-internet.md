# 0007. The storage account has no public surface at all

Accepted, 2026-08-06.

## Context

The account holds quiz result uploads. The backend reaches it with its managed identity, from
inside the network.

## Decision

`public_network_access_enabled = false`, `shared_access_key_enabled = false`, reached through a
private endpoint. The container is created with `storage_account_id`, which goes through the
Resource Manager API rather than the blob data plane. The provider is told `data_plane_available =
false`.

## Consequences

No key exists to leak, and there is no public endpoint to filter, so the `network_rules` block
sorts traffic that cannot arrive. It is kept because it is what an audit reads, and what would
still stand if public access were ever turned back on.

This one cost an apply to discover: after creating an account the provider polls its blob endpoint
with a shared key, which this account does not have, from a runner it does not admit. The account
was created and the run failed after the fact, leaving the resource tainted and the next plan
proposing to destroy it, which `prevent_destroy` then refused.

The backend's identity is granted `Storage Blob Data Contributor` on the container, not on the
account.
