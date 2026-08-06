# 0003. The backend answers the internet, guarded by an origin and a key

Accepted, 2026-07-30.

## Context

Section 6 of the brief asks that the backend be reachable from the frontend and from nothing else.
The frontend is a static site: its calls leave from the visitor's browser, from an address nobody
can know in advance. No network rule can express "only the frontend" when the frontend is a browser
anywhere in the world.

## Decision

The web app stays publicly reachable. Two things stand in for the network restriction: a CORS
policy naming the site's exact origin, and a shared `X-Api-Key` header that the backend's
`ApiKeyFilter` requires on `/api/**`.

## Consequences

This is the weakest point of the design, and it is deliberate rather than overlooked.

The key is compiled into the JavaScript bundle, so any visitor can read it. It identifies the
frontend to the backend; it authenticates nobody. CORS is enforced by the browser, so it stops a
web page on another origin, not a script. Someone with curl and the key reaches the API.

What it does buy: the API is not open to a drive-by, the origin check is one line to audit, and
everything the backend can reach in turn (database, cache, storage, vault) remains unreachable from
the internet regardless.

The one alternative that would have closed this is putting the frontend behind a runtime of its own,
which contradicts [0002](0002-app-service-over-aks.md).
