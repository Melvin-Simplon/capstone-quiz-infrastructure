# 0009. The identity allowed to write secrets is named, not inferred

Accepted, 2026-08-06.

## Context

The role assignment granting `Key Vault Secrets Officer` was keyed on
`data.azurerm_client_config.current.object_id`, that is, on whoever held the credentials at the
time. The pipeline granted the role to itself; a plan run by a person proposed to take it away from
the pipeline and hand it over. The same configuration produced two different plans depending on who
asked.

## Decision

The pipeline's object id is stated as a variable. It is an identifier, not a secret.

## Consequences

A plan reads the same whoever runs it, which is the point of a plan.

A person who needs to read one locally is granted the role separately, by hand. That is a fact
about that person, not a property of this infrastructure, and it does not belong in the state.
