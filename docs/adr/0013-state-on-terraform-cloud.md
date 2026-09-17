# 0013. The state moves to Terraform Cloud, and buys the project's first long lived secret

Accepted, 2026-09-17.

## Context

The state lived in `sttfstatempetit`, a storage account inside `mpetitRG`, the very resource group
the state describes. That group was emptied, and the state went with it.

Nothing recreated it, and nothing could. A storage account holding the state cannot be created by
the Terraform that writes into it, so it has to exist before the first `init`.
[ADR 0012](0012-the-environment-must-be-reproducible.md) named this and said
[`scripts/bootstrap-oidc.sh`](../../scripts/bootstrap-oidc.sh) created it. **It never did.** The
script only ever assigned a role on an account it expected to find. A rebuild from nothing would
have failed at `terraform init` even before the group was emptied, and the claim that this
environment can be rebuilt from this repository was never true.

Losing the state cost nothing this time, by luck: the resources were deleted in the same act, so an
empty state and an empty resource group agreed with each other. Had the state alone disappeared,
every resource would have had to be imported by hand.

## Decision

The state moves to HCP Terraform. `versions.tf` carries a `cloud` block for the workspace
`simplon-quiz-nonprod` in `WhiteMuush-Organizations`, and the `backend "azurerm"` block is gone,
along with the `Storage Blob Data Contributor` assignment the bootstrap made for it.

**The workspace runs in local execution mode.** This is not the default and the reason is specific:
in remote execution Terraform runs on HashiCorp infrastructure, at an address nothing here can
predict, while [`scripts/keyvault-firewall.sh`](../../scripts/keyvault-firewall.sh) opens the vault
for the address of the machine running the command. A remote run would open the door for the runner
and then read the vault from somewhere else, and every plan touching a secret would fail. In local
execution mode Terraform still runs on the GitHub runner, and HCP Terraform holds nothing but the
state, its versions and its lock.

Nothing was migrated. The previous state was already lost and the resource group already empty, so
the first apply creates everything from nothing.

## Consequences

**This is the first long lived secret in the project, and it contradicts a claim made everywhere
else.** Until now no client secret existed at all: every path to Azure went through OIDC, and the
README says so. HCP Terraform authenticates with a token, which now lives in
`~/.terraform.d/credentials.tfrc.json` on a workstation and in a `TF_API_TOKEN` repository secret.
That is a real cost and it is not hidden: a token that leaks gives its holder the state, and the
state describes everything.

It is worth paying here because the alternative was measured rather than imagined. This environment
has already lost its state once, silently, to an action that had nothing to do with Terraform. A
state that outlives the resource group it describes is worth more to a project whose whole claim is
that it can be rebuilt than an unbroken rule about secrets.

The bootstrap does not place that token. A script that quietly installs the only long lived
credential in a project makes it easy to forget it exists; it reports whether the secret is present
and leaves the placing to a person.

The chicken and egg problem 0012 described is gone with the storage account. What still cannot be
created by the pipeline that uses it is the app registration GitHub signs in as, and that remains
the bootstrap's only reason to exist.

`terraform init -backend=false` still skips the cloud block, so the `lint` job needs no credential.
That was verified against the real configuration rather than assumed.
