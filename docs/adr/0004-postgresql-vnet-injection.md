# 0004. PostgreSQL is injected into the network, not fronted by a private endpoint

Accepted, 2026-08-05.

## Context

Flexible Server offers both. A private endpoint leaves the public endpoint in place and filters it.
Private access injects the server into a delegated subnet and removes the public endpoint entirely.

## Decision

Private access, in `snet-postgres`, delegated to `Microsoft.DBforPostgreSQL/flexibleServers`.

## Consequences

There is no public surface left to misconfigure. Removing an attack surface beats filtering it.

The cost is a subnet that can hold nothing else, since a delegated subnet accepts exactly one
delegation, which is why the network carries three subnets rather than one.

Two details only visible once applied: `public_network_access_enabled` defaults to `true` and the
provider requires it to be set to `false` alongside a delegated subnet, and Azure adds a
`Microsoft.Storage` service endpoint to that subnet by itself, which the configuration now declares
so Terraform stops trying to take it away.
