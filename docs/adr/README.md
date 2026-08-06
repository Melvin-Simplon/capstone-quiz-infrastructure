# Decision journal

One file per decision that would be expensive to reverse, or that someone reading the Terraform
would otherwise have to reconstruct from the code. Each states what was decided, what it cost, and
what was given up.

Decisions are kept even once superseded. A journal that only holds the surviving answers hides the
reasoning that produced them.

| # | Decision | Status |
| --- | --- | --- |
| [0001](0001-github-actions.md) | GitHub Actions carries the pipelines | Accepted |
| [0002](0002-app-service-over-aks.md) | App Service and Static Web Apps, not the shared AKS cluster | Accepted |
| [0003](0003-public-backend-with-api-key.md) | The backend answers the internet, guarded by an origin and a key | Accepted |
| [0004](0004-postgresql-vnet-injection.md) | PostgreSQL is injected into the network, not fronted by a private endpoint | Accepted |
| [0005](0005-dedicated-app-service-plan.md) | The backend runs on a plan of its own | Accepted |
| [0006](0006-key-vault-firewall-outside-state.md) | The vault's allowed addresses are not part of the desired state | Accepted |
| [0007](0007-storage-closed-to-the-internet.md) | The storage account has no public surface at all | Accepted |
| [0008](0008-prevent-destroy-on-stateful-resources.md) | Terraform may not delete what holds data | Accepted |
| [0009](0009-named-deployer-identity.md) | The identity allowed to write secrets is named, not inferred | Accepted |
| [0010](0010-tag-based-discovery.md) | Pipelines find their targets by tag, never by name | Accepted |
| [0011](0011-linked-backend-not-taken.md) | The better answer to 0003, and why it was not applied | Accepted |
