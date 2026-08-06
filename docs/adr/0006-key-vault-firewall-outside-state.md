# 0006. The vault's allowed addresses are not part of the desired state

Accepted, 2026-08-06.

## Context

Reading or writing a secret goes through the Key Vault data plane, which the vault firewall
filters. The first design held the allowed address in the configuration, as a `deployer_ip`
variable the pipeline filled in with the runner's address.

It deadlocked on the second run. Terraform reads its secrets during refresh, before it can write
anything, and the addresses stored in Azure were the previous runner's. Every run was refused
before reaching the step that would have let it in: Terraform had to read the secrets in order to
earn the right to read the secrets.

## Decision

`ip_rules` stays empty in the configuration, with `ignore_changes` on it.
`scripts/keyvault-firewall.sh` opens the vault to the caller's address before a run and closes it
after, in the pipeline and by hand alike. The vault is found by tag, not by name.

## Consequences

The firewall is genuinely closed between runs, and the allowed address never outlives the job that
needed it. Plans stop churning on a value that changed every time.

The cost is that part of the vault's state lives outside Terraform, which is exactly the sort of
thing this repository otherwise refuses. It is justified here because an address that differs on
every run is not a description of the infrastructure.

A person reading a plan locally needs `Key Vault Secrets Officer` on the vault. That is a fact
about that person, so it is granted separately rather than described here, per
[0009](0009-named-deployer-identity.md).
