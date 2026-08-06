# 0002 — App Service and Static Web Apps, not the shared AKS cluster

Accepted, 2026-07-30.

## Context

The subscription offers a shared AKS cluster, `aks-nonprod-prf2026`. The application handed over is
a Spring Boot jar and an Angular bundle, already carrying the settings App Service reads:
`SPRING_PROFILES_ACTIVE`, a health endpoint on `/actuator/health`, port 8080.

## Decision

App Service for the backend, Static Web Apps for the frontend.

## Consequences

The platform handles restarts, TLS and scaling, and the deployment is a jar upload rather than a
registry, a manifest and an ingress. Nothing here would teach Kubernetes, which is the honest cost:
the harder path was refused deliberately, not by accident.

Static Web Apps has no runtime, which is what forces [0003](0003-public-backend-with-api-key.md).
