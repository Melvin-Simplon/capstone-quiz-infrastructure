# simplon-quiz-infrastructure-bilan

Terraform for the non-production environment of the Simplon quiz application on Azure. Everything
below is applied by the pipeline in this repository; nothing here is created by hand except the two
things that cannot be, listed under [Bootstrap](#bootstrap).

![Architecture](img/simplon-schéma-infrastructure-quiz.drawio.png)

| | |
| --- | --- |
| Application | <https://kind-ocean-089457b03.7.azurestaticapps.net> |
| Backend health | <https://app-simplon-quiz-mpetit.azurewebsites.net/actuator/health> |
| Resource group | `mpetitRG`, France Central |

## What is in here

A virtual network with three subnets, one per thing that needs its own: outbound integration for
the backend, the delegated subnet PostgreSQL is injected into, and the one holding the private
endpoints. Each carries a network security group.

On top of that: PostgreSQL Flexible Server, Azure Managed Redis, a storage account, a Key Vault, an
App Service Plan and the backend web app, and a Static Web App for the frontend.

Only two components answer the internet: the static site, and the backend. Everything else is
reached from inside the network, either through a private endpoint or by injection. Why the backend
is among them, and what guards it, is [0003](docs/adr/0003-public-backend-with-api-key.md).

| File | |
| --- | --- |
| `network.tf` | virtual network, subnets, security groups |
| `dns.tf` | the four private DNS zones and their links |
| `postgres.tf`, `redis.tf`, `storage.tf`, `keyvault.tf` | the data services and their private endpoints |
| `app-service.tf`, `static-web-app.tf` | the plan, the backend, the site |
| `docs/adr/` | why each of those looks the way it does |
| `docs/deployment-pipelines.md` | how the two applications get deployed onto it |

## Running it

Deployments go through the `terraform` workflow: a plan on every pull request, commented back onto
it, and an apply on merge into `main`. A local run is for reading a plan, and takes two steps
because Terraform reads the vault's secrets over the data plane, which its firewall filters:

```sh
scripts/keyvault-firewall.sh add
terraform plan
scripts/keyvault-firewall.sh remove
```

Reading a plan locally also needs `Key Vault Secrets Officer` on the vault. The pipeline's identity
has it; a person has to be granted it separately, and
[0009](docs/adr/0009-named-deployer-identity.md) explains why that is not in the configuration.

Deleting anything that holds data is refused on purpose, so tearing this environment down starts by
removing the `prevent_destroy` blocks, deliberately, in a commit of its own. See
[0008](docs/adr/0008-prevent-destroy-on-stateful-resources.md).

## Bootstrap

Two things cannot be created by the Terraform that consumes them, so
[`scripts/bootstrap-oidc.sh`](scripts/bootstrap-oidc.sh) creates them once:

- the storage account holding the remote state, reached with an Azure AD identity rather than a key
- the app registration GitHub authenticates as, with one federated credential per repository and
  per context, and the role assignments that go with it

No client secret exists anywhere. Each workflow proves which repository, branch and environment it
runs from, and Azure hands back a token that expires with the job.

## Decisions

[docs/adr](docs/adr/README.md) holds one file per decision worth defending, including the ones that
cost an apply to discover. Start with
[0003](docs/adr/0003-public-backend-with-api-key.md) for the weakest point of the design and
[0005](docs/adr/0005-dedicated-app-service-plan.md) for the constraint that forced this environment
off the shared App Service plan.

## Branches

- `main`: applied to Azure
- `develop`: integration
- `feat/*`, `fix/*`, `ci/*`, `docs/*`, `chore/*`: one per change, merged into `develop` by pull
  request

Both protected branches refuse deletion, force-pushes, unsigned commits, direct writes, and any
merge whose checks have not passed.
