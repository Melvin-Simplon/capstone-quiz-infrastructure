# 0011 — The backend was not put behind the Static Web App, and should be

Accepted, 2026-08-06. Records a better answer than
[0003](0003-public-backend-with-api-key.md), deliberately not applied here.

## Context

[0003](0003-public-backend-with-api-key.md) leaves the backend answering the internet, guarded by a
CORS origin and a key compiled into the frontend bundle. Both are weak, and were accepted because a
static site's calls come from a browser whose address nobody can know in advance.

Static Web Apps answers exactly that problem, and this was found after the fact. Linking an App
Service as a "bring your own API" backend makes Static Web Apps proxy every `/api` request to it,
and Microsoft states the effect plainly:

> By default, when an App Service app is linked to a static web app, the App Service app only
> accepts requests that are proxied through the linked static web app.

Linking installs an identity provider named `Azure Static Web Apps (Linked)` on the web app, which
refuses anything arriving by another road.

## What that would fix

The API key disappears from the bundle, because the browser calls `/api/...` on the site's own
origin and never holds a credential. CORS disappears with it, same origin. Section 6 of the brief
becomes true rather than approximated: the backend really is reachable from the frontend and from
nowhere else, enforced by the platform instead of by a shared string.

The frontend deployment pipeline loses its longest part, the one that reads a secret out of the
vault and bakes it into a build.

## Decision

Not applied, on 2026-08-06, with the environment working end to end.

## Why not

Four costs, two of which land on things this project is judged on.

- Static Web Apps has to move from Free to **Standard**, which is billed. Bring your own API does
  not exist on the free plan.
- **The link cannot be expressed in Terraform.** The provider offers
  `azurerm_static_web_app_function_app_registration` and nothing equivalent for a web app, so it
  would be an `az staticwebapp backends link` call outside the configuration, on a project whose
  point is that the configuration describes everything.
- The identity provider would also refuse `/actuator/health`, so the App Service health probe and
  the deployment's own check would fail until that path is excluded through `auth_settings_v2`.
- The static web app is in West Europe and the web app in France Central, since Static Web Apps is
  not offered in France Central. Nothing in the documentation forbids linking across regions, and
  nothing confirms it either. It was not tested.

Swapping a known weakness for an untested arrangement, on the day the environment first worked from
end to end, buys nothing that a written record does not.

## Consequences

[0003](0003-public-backend-with-api-key.md) stands, and is now the deliberate answer rather than
the only one known. Anyone continuing this work should start here: move the static web app to
Standard, link the backend, exclude the health path, then delete the API key from the vault, the
filter from the backend and the substitution step from the frontend pipeline.
