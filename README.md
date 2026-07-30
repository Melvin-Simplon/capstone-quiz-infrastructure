# simplon-quiz-infrastructure-bilan

Terraform infrastructure for the non-production environment of the Simplon quiz app on Azure.

![Architecture](img/simplon-schéma-infrastructure-quiz.drawio.png)

## Stack

App Service (backend), Static Web Apps (frontend), PostgreSQL Flexible Server, Azure Managed
Redis, Storage Account, Key Vault. All in `mpetitRG`. The App Service Plan `plan-npr-prf2026` is
shared and only referenced.

## Branches

- `main`: deployed to Azure
- `develop`: integration
- `feature/*`: one per change, merged into `develop` via pull request
