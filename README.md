# Simplon Quiz Infrastructure

[![terraform](https://github.com/WhiteMuush/simplon-quiz-infrastructure-bilan/actions/workflows/terraform.yml/badge.svg?branch=main)](https://github.com/WhiteMuush/simplon-quiz-infrastructure-bilan/actions/workflows/terraform.yml)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.9-7B42BC?logo=terraform&logoColor=white)](versions.tf)
[![azurerm](https://img.shields.io/badge/azurerm-~%3E4.0-0078D4?logo=microsoftazure&logoColor=white)](versions.tf)
[![Region](https://img.shields.io/badge/region-France%20Central-0078D4)](#what-is-deployed)
[![Auth](https://img.shields.io/badge/auth-OIDC%2C%20no%20stored%20secret-2EA043)](#bootstrap)
[![State](https://img.shields.io/badge/state-remote%2C%20Entra%20ID-2EA043)](versions.tf)

Terraform for the non-production environment of the Simplon quiz application on Azure. Every
resource below is applied by this repository's pipeline. The only two things created by hand are
the ones that cannot create themselves, and they are listed under [Bootstrap](#bootstrap).

| | |
| --- | --- |
| Application | <https://kind-ocean-089457b03.7.azurestaticapps.net> |
| Backend health | <https://app-simplon-quiz-mpetit.azurewebsites.net/actuator/health> |
| Resource group | `mpetitRG`, France Central |
| Pipeline | plan on every pull request, apply on merge into `main` |

---

## What is deployed

A virtual network with three subnets, one for each thing that needs its own: outbound integration
for the backend, the delegated subnet PostgreSQL is injected into, and the one holding the private
endpoints. Each carries its own network security group.

On top of it: PostgreSQL Flexible Server, Azure Managed Redis, a storage account, a Key Vault, an
App Service Plan with the backend web app, and a Static Web App for the frontend.

Two components answer the internet, and only two: the static site, and the backend. Everything else
is reached from inside the network, through a private endpoint or by injection. Why the backend is
among them, and what guards it, is [ADR 0003](docs/adr/0003-public-backend-with-api-key.md), and
what should replace it is [ADR 0011](docs/adr/0011-linked-backend-not-taken.md).

## Repository layout

| Path | Holds |
| --- | --- |
| `network.tf` | virtual network, subnets, security groups |
| `dns.tf` | the four private DNS zones and their virtual network links |
| `postgres.tf`, `redis.tf`, `storage.tf`, `keyvault.tf` | data services and their private endpoints |
| `app-service.tf`, `static-web-app.tf` | the plan, the backend, the site |
| `scripts/` | the two things that live outside Terraform, and why |
| `docs/adr/` | one file per decision worth defending |
| `docs/deployment-pipelines.md` | how the two applications reach this infrastructure |

## Running it

Deployments go through the `terraform` workflow. A local run is for reading a plan, and takes two
steps, because Terraform reads the vault's secrets over the data plane and the vault's firewall
filters it:

```sh
scripts/keyvault-firewall.sh add
terraform plan
scripts/keyvault-firewall.sh remove
```

Reading a plan locally also needs the `Key Vault Secrets Officer` role on the vault. The pipeline's
identity holds it; a person is granted it separately, and
[ADR 0009](docs/adr/0009-named-deployer-identity.md) explains why that grant is not in the
configuration.

Deleting anything holding data is refused on purpose. Tearing this environment down therefore
begins by removing the `prevent_destroy` blocks, deliberately, in a commit of its own, see
[ADR 0008](docs/adr/0008-prevent-destroy-on-stateful-resources.md).

## Bootstrap

Two things cannot be created by the Terraform that consumes them.
[`scripts/bootstrap-oidc.sh`](scripts/bootstrap-oidc.sh) creates them once:

- the storage account holding the remote state, reached with an Entra ID identity rather than a key
- the app registration GitHub authenticates as, with one federated credential per repository and
  per context, plus the role assignments that go with it

No client secret exists anywhere. Each workflow proves which repository, branch and environment it
runs from, and Azure returns a token that expires with the job.

## Decisions

[docs/adr](docs/adr/README.md) holds one record per decision, including the four that only became
apparent by applying. Two are worth opening first:

- [ADR 0003](docs/adr/0003-public-backend-with-api-key.md): the weakest point of the design,
  named rather than hidden
- [ADR 0005](docs/adr/0005-dedicated-app-service-plan.md): the platform limit that forced this
  environment off the promotion's shared App Service plan

## Branches

| Branch | Role |
| --- | --- |
| `main` | applied to Azure |
| `develop` | integration |
| `feat/*`, `fix/*`, `ci/*`, `docs/*`, `chore/*` | one per change, merged into `develop` by pull request |

Both protected branches refuse deletion, force-pushes, unsigned commits, direct writes, and any
merge whose checks have not passed.
