# Makefile orchestration of the deployment pipelines

Design, 2026-09-17.

## Context

The project spans three repositories, each carrying its own pipeline:

| Repository | Workflow | What it does |
| --- | --- | --- |
| `Melvin-Simplon/capstone-quiz-infrastructure` | `terraform.yml` | Plans on pull request, applies on push to `main` |
| `Melvin-Simplon/capstone-quiz-backend` | `ci-cd.yml` | Builds, tests, deploys the jar to App Service |
| `Melvin-Simplon/capstone-quiz-frontend` | `ci-cd.yml` | Builds the site, deploys it to Static Web Apps |

Deploying the whole project today means opening three browser tabs, merging three
pull requests in the right order, and remembering which one has to land first.
Nothing records that order, and nothing enforces it.

Four facts make this worse than an ergonomic problem. They were established by
inspecting the live subscription and the app registration on 2026-09-17.

**The resource group `mpetitRG` is empty.** Every resource is gone, including the
storage account `sttfstatempetit` that held the Terraform state. That account is
created by `scripts/bootstrap-oidc.sh`, outside Terraform, so nothing recreates it
on its own. The state is lost, and reality is empty, so the two agree.

**The federated credentials no longer match the repositories.** The three
repositories were transferred from the `WhiteMuush` account to the
`Melvin-Simplon` organisation and renamed. Their numeric ids are unchanged, which
proves they are the same repositories, but the nine federated credentials on the
app registration still name the old owner and the old repository names:

```
credential subject : repo:WhiteMuush@78932427/simplon-quiz-backend-bilan@1316972691:...
GitHub now signs   : repo:Melvin-Simplon@327876306/capstone-quiz-backend@1316972691:...
```

No workflow in any of the three repositories can obtain an Azure token. Every
`azure/login` step fails. The pipelines are not merely idle, they are broken at
the identity layer.

**`scripts/bootstrap-oidc.sh` is frozen on the old names.** It hardcodes
`OWNER="WhiteMuush"` and the three `simplon-quiz-*-bilan` repository names, so
running it unchanged would recreate exactly the same wrong credentials.

**No workflow can be triggered by hand.** None of the three declares
`workflow_dispatch`. The only way into a deployment is a push to `main`.

## Decision

A `Makefile` at the root of this repository drives the existing pipelines from the
workstation. It triggers workflows, follows their runs and chains the three
repositories in the order the deployment actually requires.

No deployment target touches Azure. Every change to the infrastructure or to a
running application is made by a GitHub runner, through the OIDC trust that is
already in place. `deploy`, `infra`, `backend`, `frontend`, `plan`, `status`,
`logs` and `destroy` need nothing on the workstation but `gh`: no Azure
credential, no Terraform binary, no JDK, no Node toolchain.

Two targets are the exception, and they are about identity rather than
deployment. `bootstrap` creates and repairs the federated credentials and the
role assignments, and `doctor` reads those credentials back to check them. Both
call `az` and both need a session holding Owner and Role Based Access
Administrator on `mpetitRG`, which the current account has. This is the one-off
setup the pipelines cannot perform on themselves, for the reason ADR 0012 already
records: the identity that GitHub signs in as cannot be created by the pipeline
that signs in with it.

This was a deliberate choice over two rejected alternatives:

**Deploying directly from the workstation** was rejected because it duplicates the
pipeline logic in a second place, which then drifts, and because it requires
credentials and a toolchain locally. The workstation currently has no JDK,
Terraform 1.15.8 against the 1.9.8 the pipelines pin, and Node 22 against the 25
the frontend requires. A local `terraform apply` on 1.15.8 would write a state
file that the pipelines on 1.9.8 could no longer read, disabling the CI.

**A containerised local toolchain** would have solved the version drift but not
the duplication, and it still puts Azure credentials on the workstation.

## Prerequisites this work has to repair

The Makefile is useless against broken pipelines, so repairing them is part of the
work rather than a precondition for it.

### Federated credentials

`scripts/bootstrap-oidc.sh` is corrected to read the owner and repository names
from variables defaulting to the current identities, and its state storage section
is removed (see below). Re-running it replaces the nine stale credentials.

### Manual triggers

`workflow_dispatch` is added to the three workflows. This alone is not enough, and
the reason is easy to miss: the deployment jobs are guarded by
`if: github.event_name == 'push'` and the infrastructure plan by
`if: github.event_name == 'pull_request'`. Triggered by hand, those jobs would be
skipped and the run would finish green having deployed nothing.

The guards are therefore rewritten:

- Backend and frontend: the deploy job runs on `push` **or** on `workflow_dispatch`.
- Infrastructure: `workflow_dispatch` takes an `action` input of `plan` or `apply`,
  and the two jobs key off that input rather than off the event name alone.

### Terraform state

The state moves to HCP Terraform. The `backend "azurerm"` block in `versions.tf`
becomes a `cloud` block, and the storage account disappears from the bootstrap
along with the `Storage Blob Data Contributor` assignment it needed.

The workspace runs in **local execution mode**. This is not the default and it
matters: in remote execution Terraform runs on HashiCorp infrastructure, at an
address nothing here can predict, while `scripts/keyvault-firewall.sh` opens the
vault for the address of the machine running the command. A remote run would open
the door for the runner and then read the vault from somewhere else, and the plan
would fail. In local execution mode Terraform still runs on the GitHub runner and
HCP Terraform holds nothing but the state, its versions and its lock.

Nothing is migrated. The previous state is already lost and the resource group is
already empty, so the first apply creates everything from nothing.

This is the first long lived secret in the project, and it is a real cost. The
architecture so far claims that no client secret exists anywhere, because every
authentication path goes through OIDC. A `TF_API_TOKEN` secret in the three
repositories breaks that claim. An ADR records the trade and the reason: a state
file that survives the deletion of the resource group it describes is worth more
here than an unbroken rule, given that this environment has already lost its state
once.

## The Makefile

### Layout

```
Makefile                        entry point: configuration, includes, nothing else
makefiles/
  help.mk                       the default target, built from the target comments
  doctor.mk                     doctor
  bootstrap.mk                  bootstrap
  infra.mk                      plan, infra, destroy
  backend.mk                    backend
  frontend.mk                   frontend
  deploy.mk                     deploy, one-shot
  status.mk                     status, logs
scripts/
  bootstrap-oidc.sh             existing, corrected for the new repository names
  keyvault-firewall.sh          existing, called by the workflows and not from here
  pipeline/
    lib.sh                      sourced by the others: logging, guards, gh helpers
    doctor.sh                   every prerequisite check
    dispatch.sh                 dispatch one workflow and follow its run
    status.sh                   last runs, and the URLs when az is available
    destroy.sh                  the confirmation and the dispatch
```

The separation is strict and it is the point of the structure. A `.mk` fragment
declares targets, wires dependencies between them and passes configuration down.
It holds no logic, no loop and no conditional beyond target prerequisites. Every
decision lives in a script under `scripts/pipeline/`, which is testable on its own,
readable by someone who does not know Make, and debuggable by running it directly.

The root `Makefile` carries the configuration that everything else reads, the
organisation and the three repository names, the resource group, the HCP
workspace, and it includes the fragments. It declares no target of its own beyond
setting `help` as the default goal, so that a bare `make` lists what exists rather
than deploying anything.

`dispatch.sh` is the single place that knows how to trigger a workflow and follow
its run. `infra`, `backend` and `frontend` all call it with different arguments
rather than each repeating the `gh workflow run` and `gh run watch` pair. When the
way a run is followed has to change, it changes once.

All recipes run under `bash` with `set -euo pipefail`, set once in the root
`Makefile` through `SHELL` and `.SHELLFLAGS` rather than repeated per recipe.

### Targets

| Target | Effect |
| --- | --- |
| `help` | Lists the targets. The default target, so a bare `make` never deploys |
| `doctor` | Checks `gh` authentication, the federated credentials against what GitHub signs, the presence of `workflow_dispatch`, the HCP token and the workspace |
| `bootstrap` | Runs the corrected `bootstrap-oidc.sh`: credentials, role assignments, repository variables, `nonprod` environments, `TF_API_TOKEN` |
| `plan` | Dispatches the infrastructure workflow with `action=plan` and prints the plan |
| `infra` | Dispatches it with `action=apply` and waits for the run |
| `backend` | Dispatches the backend pipeline and waits for the health check to answer `UP` |
| `frontend` | Dispatches the frontend pipeline and waits for the site check |
| `deploy` | `infra`, then `backend`, then `frontend`, stopping at the first failure |
| `one-shot` | `doctor`, then `bootstrap`, then `deploy`, from an empty environment |
| `status` | The last run of each repository. Adds the deployed URLs, resolved by tag, when an `az` session is available, and says so when it is not |
| `logs` | Follows the run currently in progress |
| `destroy` | Dispatches `terraform-destroy.yml` with the resource group name |

### Ordering

`deploy` runs the three in sequence because the dependencies are real. The
infrastructure has to exist before anything is deployed onto it. The backend has
to answer before the frontend is verified, since the frontend pipeline ends by
calling the API and demanding JSON. The frontend has to be rebuilt after any
infrastructure rebuild, because the API key is a `random_password` that changes
whenever the vault is recreated.

Nothing today records this order. The Makefile is where it becomes executable.

### Resumability

Every step of `one-shot` first asks whether it is already done, and skips itself if
so. `bootstrap` is skipped when the credentials already match what GitHub signs.
`infra` is skipped when the plan is empty.

This is what makes `one-shot` usable rather than merely short. A full build takes
roughly half an hour, most of it Postgres and the private endpoints. When it fails
at minute twelve, the same command picks up where it stopped instead of starting
over.

### What stays outside

Two things cannot be folded in, and `doctor` stops on them with the command to run:

- `terraform login` opens a browser. The current token returns 401 and has to be
  renewed by hand.
- An approval required on the `nonprod` environment waits for a human. The
  Makefile reports that the run is waiting rather than appearing to hang.

### Error handling

Each recipe runs under `set -euo pipefail`. A dispatched run is followed with
`gh run watch --exit-status`, so a failed run fails the target, which stops the
chain. When a run fails, the target prints the URL of the failed job rather than
its log, because the log belongs on the screen the user chooses to open.

`doctor` is the only target that reports several problems at once. Everything else
stops at the first.

## Documentation corrected along the way

Two documents describe a guard that no longer exists. ADR 0012 removed the seven
`prevent_destroy` blocks, but:

- `README.md`, under "Running it", still states that deleting anything holding data
  is refused and that a teardown begins by removing those blocks.
- `.github/workflows/terraform-destroy.yml`, line 72, still comments that the
  destroy stops on the first resource carrying `prevent_destroy` and that the
  database, the storage account and the vault are not disposable.

Both are corrected here. The second is the dangerous one: someone reading it while
typing the resource group name into the dispatch form believes they have a net that
was removed.

## Testing

The Makefile is shell glue over `gh`, and its failure modes are about what it does
when the world is not as expected. Those are the cases worth covering:

- `doctor` reports each broken prerequisite, separately and by name: missing `gh`
  authentication, stale federated credentials, absent `workflow_dispatch`, expired
  HCP token.
- A workflow dispatched into a failing run makes its target exit non zero.
- `deploy` stops after a failed `infra` and does not dispatch the backend.
- `one-shot` re-run after a successful `bootstrap` skips it.
- `destroy` refuses a resource group name that does not match.

The pipelines themselves are already covered by their own jobs and are not retested
here.

## Consequences

Deploying the whole project becomes one command from an empty environment, and the
order the three repositories depend on stops living in somebody's memory.

The cost is a fourth place where the deployment is described. The Makefile does not
duplicate the pipelines, it calls them, so it cannot drift on how anything is built
or deployed. It can drift on their names, their inputs and their order, and that is
the failure to watch for: a workflow renamed or an input added without the Makefile
following.
