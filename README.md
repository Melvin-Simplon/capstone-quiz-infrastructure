# Simplon Quiz Infrastructure

[![CI - Build module](https://github.com/Melvin-Simplon/capstone-quiz-infrastructure/actions/workflows/ci-build.yml/badge.svg?branch=main)](https://github.com/Melvin-Simplon/capstone-quiz-infrastructure/actions/workflows/ci-build.yml)
[![CI - Security scan](https://github.com/Melvin-Simplon/capstone-quiz-infrastructure/actions/workflows/ci-security.yml/badge.svg?branch=main)](https://github.com/Melvin-Simplon/capstone-quiz-infrastructure/actions/workflows/ci-security.yml)
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
| Pipeline | plan on every pull request, apply only when asked for |

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
| `.github/workflows/` | one file per category, see [The pipeline](#the-pipeline) |
| `scripts/workflows/` | what the pipeline runs, one script per step with logic |
| `scripts/pipeline/` | what the Makefile runs from a workstation |
| `scripts/bootstrap-oidc.sh` | the one thing Terraform cannot create for itself |
| `docs/adr/` | one file per decision worth defending |
| `docs/design/` | designs written before the code, kept for the reasoning |
| `docs/deployment-pipelines.md` | how the two applications reach this infrastructure |

## The pipeline

Four workflow files, one per kind of work, the same split as the two application repositories.
Each job is named after its category and its tool, so a check reads `Lint (tflint)` or
`IaC (Trivy)`. All of them share `scripts/workflows/lib.sh`, byte for byte, so a job log reads the
same in all three.

| File | Name | Jobs | Runs on |
| --- | --- | --- | --- |
| `ci-build.yml` | CI - Build module | `Lint (Terraform fmt and validate)`, `Lint (tflint)`, `Plan (Terraform)` | pull request, `make plan`, called by `cd-apply.yml` |
| `ci-security.yml` | CI - Security scan | `Secrets (gitleaks and Trivy)`, `IaC (Trivy)` | pull request, called by `cd-apply.yml` |
| `cd-apply.yml` | CD - Apply | build and security first, then `Apply (Terraform)` | `make infra` only |
| `cd-destroy.yml` | CD - Destroy | `destroy` | manual only, and only after typing the resource group name |

`IaC (Trivy)` is this repository's equivalent of the SAST category elsewhere: it reads the
configuration as infrastructure, not the code that runs on it.

The two lint jobs are handed no secret at all. Both run `terraform init -backend=false`, which
skips the cloud block, so neither needs the HCP Terraform token nor an Azure credential.

The plan is skipped on Dependabot runs. GitHub hands those a separate, empty secret store, so
`TF_API_TOKEN` arrives blank and `terraform init` stops on "Required token could not be found",
failing a required check on a branch that only bumps a provider. `Lint (Terraform fmt and validate)`
still installs the bumped provider and validates against it, so the bump is not merged unverified.

Applying is never a side effect of a merge, and a push to `main` runs nothing at all: every check
already passed on the pull request. An apply on every push would assume `main` should always be
applied and that an environment not matching it is drift to correct, and that is not this project:
the environment is destroyed between sessions on purpose, so most of the time `main` describes
something that deliberately does not exist. Building is `make infra`, which dispatches
`cd-apply.yml`. It runs the lint and security jobs first, and leaves the plan out: the pull request
already showed it.

`plan`, `apply` and `destroy` share one concurrency group, `terraform-state-nonprod`, because the
state is a single blob and two runs would fight over its lease. One consequence is worth knowing: a
run waiting on the `nonprod` approval holds that group while it waits, and `timeout-minutes` does
not help, because a job that has not started has no clock running. A plan queued behind an
unapproved apply or destroy stays queued until that one is approved or cancelled.

The workflow **file names** are a public interface. `make` dispatches `cd-apply.yml`,
`ci-build.yml` and `cd-destroy.yml` here, and `cd-deploy.yml` in the two application repositories,
by name, and `make doctor` checks that each one exists.

## Running it

The Makefile is the way in. Nothing in it touches Azure directly: each target dispatches a workflow
in one of the three repositories and follows its run, so a deployment started from a workstation
leaves the same trace as one started from GitHub. `make help` lists the targets:

![Output of make help: the targets grouped as Setup, Deploy, Inspect, Teardown and Help, each with
a one line description, under a warning that destroy tears down the whole environment and nothing is
protected any more](img/make-help.png)

`make one-shot` is the one to know for an empty environment: it builds the infrastructure, then
deploys the backend and the frontend in that order, and it is resumable after a failure.

A local run is for reading a plan, and takes two steps, because Terraform reads the vault's secrets
over the data plane and the vault's firewall filters it:

```sh
scripts/workflows/deploy/keyvault-firewall.sh add
terraform plan
scripts/workflows/deploy/keyvault-firewall.sh remove
```

Reading a plan locally also needs the `Key Vault Secrets Officer` role on the vault. The pipeline's
identity holds it; a person is granted it separately, and
[ADR 0009](docs/adr/0009-named-deployer-identity.md) explains why that grant is not in the
configuration.

Nothing is protected from deletion. [ADR 0012](docs/adr/0012-the-environment-must-be-reproducible.md)
removed the `prevent_destroy` blocks that [ADR 0008](docs/adr/0008-prevent-destroy-on-stateful-resources.md)
had put on the seven resources holding state, so that this environment can actually be rebuilt from
this repository rather than only claiming it can. Tearing it down is the
[destroy workflow](.github/workflows/cd-destroy.yml), or `make destroy`, and it takes the
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
