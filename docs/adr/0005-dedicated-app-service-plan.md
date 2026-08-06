# 0005 — The backend runs on a plan of its own

Accepted, 2026-08-06.

## Context

The intended host was the promotion's shared plan, `plan-npr-prf2026`, referenced as a data source
so that nobody would duplicate a resource everyone depends on. The first deployment of the web app
failed:

```
409 Conflict: Adding this VNET would exceed the App Service Plan VNET limit of 2.
```

The two slots were held by another trainee's network and by the trainer's. Microsoft states the
limit in terms of hardware: two virtual interfaces per worker, therefore two virtual network
integrations per plan. It does not move with the pricing tier, so asking for a bigger shared plan
would not have helped, and only two people in the promotion can ever integrate a network there.

Dropping VNet integration was the only other way out, and it is not one: after
[0004](0004-postgresql-vnet-injection.md) the database has no public endpoint at all, and the cache,
the storage account and the vault are reached through private endpoints. Without integration the
backend reaches none of its dependencies.

## Decision

A dedicated `azurerm_service_plan`, B1 Linux, in `mpetitRG`. The SKU is a variable.

## Consequences

A shared resource is no longer shared, which is a small cost charged to this environment alone, and
the smallest tier that still carries VNet integration, Always On and the health check was chosen
rather than the comfortable one.

The `Reader` grant on `rg-shared-prf2026` was removed along with the data source that needed it.

Worth passing on to the promotion: whoever integrates a network on the shared plan next will hit
the same wall, and there is no third place.
