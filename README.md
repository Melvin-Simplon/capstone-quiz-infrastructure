# simplon-quiz-infrastructure-bilan

Terraform infrastructure for the non-production environment of the Simplon quiz app on Azure.

![Architecture](img/simplon-schéma-infrastructure-quiz.drawio.png)

## Stack

App Service (backend), Static Web Apps (frontend), PostgreSQL Flexible Server, Azure Managed
Redis, Storage Account, Key Vault. All in `mpetitRG`. The App Service Plan `plan-npr-prf2026` is
shared and only referenced.

## Running it

Deployments go through the `terraform` workflow. A local run is for reading a plan, and needs one
input the pipeline resolves by itself:

```sh
terraform plan -var "deployer_ip=$(curl -fsS https://api.ipify.org)"
```

Key Vault secrets are written over the data plane, which the vault firewall filters. Whoever runs
Terraform therefore has to be let through, and that rule is rewritten on every run since the
address changes. The storage account needs nothing of the sort: it is closed to the internet
altogether, its container being created over the Resource Manager API.

The database server, the storage account and its container, the vault and its secrets carry
`prevent_destroy`. Terraform refuses to delete them, and refuses any change that would recreate
them. Tearing the environment down therefore starts by removing those blocks, deliberately, in a
commit of its own.

## Branches

- `main`: deployed to Azure
- `develop`: integration
- `feature/*`: one per change, merged into `develop` via pull request
