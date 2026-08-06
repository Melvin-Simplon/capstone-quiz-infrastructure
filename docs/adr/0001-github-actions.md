# 0001 — GitHub Actions carries the pipelines

Accepted, 2026-07-30.

## Context

The three repositories are on GitHub. The alternative on the table was GitLab CI, which would have
meant either mirroring the repositories or moving them.

## Decision

GitHub Actions, in all three repositories.

## Consequences

Dependabot, secret scanning and push protection come with the platform rather than being wired up
separately, and CodeQL is free because the repositories are public. Authentication to Azure is by
OpenID Connect, so no credential is stored anywhere.

The cost is a tie to one vendor for the automation as well as the hosting of the code.
