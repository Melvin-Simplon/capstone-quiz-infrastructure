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

![Architecture of the non-production environment: the three repositories and their pipelines, the
OIDC sign-in into Azure, and the resource group with its virtual network, its three subnets and the
services they hold](img/simplon-sch%C3%A9ma-infrastructure-quiz.drawio.png)

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

Nothing is protected from deletion. [ADR 0012](docs/adr/0012-the-environment-must-be-reproducible.md)
removed the `prevent_destroy` blocks that [ADR 0008](docs/adr/0008-prevent-destroy-on-stateful-resources.md)
had put on the seven resources holding state, so that this environment can actually be rebuilt from
this repository rather than only claiming it can. Tearing it down is the
[destroy workflow](.github/workflows/terraform-destroy.yml), or `make destroy`, and it takes the
database with it.

## Bootstrap

One thing cannot be created by the Terraform that consumes it, and
[`scripts/bootstrap-oidc.sh`](scripts/bootstrap-oidc.sh) creates it once: the app registration
GitHub authenticates as, with one federated credential per repository and per context, plus the
role assignments that go with it. Run it with `make bootstrap`.

Every path to Azure goes through OIDC. Each workflow proves which repository, branch and
environment it runs from, and Azure returns a token that expires with the job, so no Azure
credential is stored anywhere.

There is exactly one long lived secret, and it is not an Azure one. The state lives on HCP
Terraform, which authenticates with a token: `TF_API_TOKEN` as a repository secret, and a local
`terraform login` for a plan read from a workstation.
[ADR 0013](docs/adr/0013-state-on-terraform-cloud.md) records what that costs and why it is worth
paying here.

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
