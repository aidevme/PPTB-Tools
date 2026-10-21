# UI actions and their CLI or API equivalents

<!-- cspell:ignore cdsproj pcf PublishXml PublishAllXml WhoAmI odata -->

Use this table in Phase 4 to replace recorded clicks with commands. It covers common Power Platform, Dynamics 365 CE,
Dataverse, Copilot Studio, PCF, GitHub and Azure DevOps actions; it isn't complete.

**Before a command goes into a generated skill, check it** against its documentation or `<tool> <command> --help`:
flags change between versions. The entries below were checked on 2026-10-21 against the source in the last column
(`gh` 2.x help; Microsoft Learn for `pac`, `az devops` and the Dataverse Web API). If no row fits, look the action up
in the official documentation; never invent a command, flag or endpoint. If nothing exists, keep the UI step and mark
it **Fragile (UI)**.

Placeholders follow the [redaction checklist](redaction-checklist.md): `{{environmentUrl}}`, `{{solutionName}}` and
so on.

## Sign-in and context

| Recorded UI action | Equivalent | Checked against |
| --- | --- | --- |
| Pick an environment in make.powerapps.com | `pac auth create --environment {{environmentUrl}}`, or `pac env select --environment {{environmentUrl}}` for an existing profile | Learn: pac auth, pac env |
| See which environment and user you're on | `pac env who`; Web API `GET {{environmentUrl}}/api/data/v9.2/WhoAmI` | Learn: pac env; WhoAmI function |
| Browse the environments list | `pac env list`; tenant-wide `pac admin list` (`--type Sandbox`, `--json`) | Learn: pac env, pac admin |
| Sign in to Azure / pick a subscription | `az login`; `az account set --subscription {{subscriptionId}}` | az help |
| Set the Azure DevOps organization and project | `az devops configure --defaults organization={{adoOrgUrl}} project={{adoProject}}` (needs the `azure-devops` extension: `az extension add --name azure-devops`) | Learn: Azure DevOps CLI |
| Sign in to GitHub | `gh auth login`; check with `gh auth status` | gh help |

## Solutions (Power Platform and Dataverse)

| Recorded UI action | Equivalent | Checked against |
| --- | --- | --- |
| Solutions > Export (managed or unmanaged) | `pac solution export --name {{solutionName}} --path {{zipPath}} [--managed]`; Web API `ExportSolution` action | Learn: pac solution; Dataverse solution API |
| Solutions > Import | `pac solution import --path {{zipPath}} [--publish-changes] [--settings-file {{settingsFile}}]`; Web API `ImportSolution` action. **Destructive on the target: confirm first** | Learn: pac solution |
| Publish all customizations | `pac solution publish`; Web API `PublishAllXml` action | Learn: pac solution |
| Publish selected components | Web API `PublishXml` action with a `ParameterXml` listing them | Learn: PublishXml |
| Look at the solutions and their versions | `pac solution list [--json]`; `pac solution online-version --solution-name {{solutionName}}` | Learn: pac solution |
| Set a solution's version | `pac solution online-version --solution-name {{solutionName}} --solution-version {{version}}` | Learn: pac solution |
| Add an existing component to a solution | `pac solution add-solution-component --solutionUniqueName {{solutionName}} --component {{component}} --componentType {{type}}` | Learn: pac solution |
| Download a solution into source control | `pac solution clone --name {{solutionName}}` (project with `.cdsproj`), or export then `pac solution unpack --zipfile {{zipPath}} --folder {{folder}}` | Learn: pac solution |
| Pack source back into a zip | `pac solution pack --zipfile {{zipPath}} --folder {{folder}}` | Learn: pac solution |
| Run Solution checker | `pac solution check --path {{zipPath}} --outputDirectory {{folder}}` | Learn: pac solution |
| Delete a solution | `pac solution delete --solution-name {{solutionName}}`. **Destructive: confirm first** | Learn: pac solution |

## Data (Dataverse Web API)

Base URL: `{{environmentUrl}}/api/data/v9.2/`, with the `Authorization: Bearer` header from a sign-in, never a pasted
token.

| Recorded UI action | Equivalent | Checked against |
| --- | --- | --- |
| Open a view or Advanced Find | `GET /{{entitySetName}}?$select=…&$filter=…`; FetchXML with `pac env fetch --xml "<fetch>…</fetch>"` | Learn: Web API query; pac env |
| Create a record from a form | `POST /{{entitySetName}}` with the column values | Learn: create a table row |
| Edit a record and save | `PATCH /{{entitySetName}}({{recordId}})` | Learn: update and delete rows |
| Delete a record | `DELETE /{{entitySetName}}({{recordId}})`. **Destructive: confirm first** | Learn: update and delete rows |
| Many records at once | a `$batch` request | Learn: batch operations |

## Environments and admin

| Recorded UI action | Equivalent | Checked against |
| --- | --- | --- |
| Back up an environment | `pac admin backup` (see `pac admin backup --help` for its parameters) | Learn: pac admin |
| Copy an environment | `pac admin copy`. **Overwrites the target: confirm first** | Learn: pac admin |
| Create an environment | `pac admin create` | Learn: pac admin |
| Delete an environment | `pac admin delete`. **Destructive: confirm first** | Learn: pac admin |
| Assign a user a security role | `pac admin assign-user` | Learn: pac admin |
| List security roles | `pac admin list-roles` | Learn: pac admin |

## Copilot Studio and PCF

| Recorded UI action | Equivalent | Checked against |
| --- | --- | --- |
| List agents in an environment | `pac copilot list [--environment {{environmentUrl}}]` | Learn: pac copilot |
| Download an agent to edit locally | `pac copilot clone --bot {{agentId}} --environment {{environmentUrl}} --output-dir {{folder}}` | Learn: pac copilot |
| Upload local agent changes | `pac copilot pull` first, then `pac copilot push` (inside a workspace from `clone` or `init`) | Learn: pac copilot |
| Publish an agent | `pac copilot publish` (check `--help` for its parameters). Publishing changes what users see: confirm first | Learn: pac copilot |
| Import a PCF control for testing | `pac pcf push --publisher-prefix {{publisherPrefix}} [--solution-unique-name {{solutionName}}]` | Learn: pac pcf |

## GitHub

| Recorded UI action | Equivalent | Checked against |
| --- | --- | --- |
| New pull request | `gh pr create --title {{title}} --body {{body}} --base {{baseBranch}} [--head {{branch}}] [--draft] [--reviewer {{reviewer}}]` | gh help |
| New issue | `gh issue create --title {{title}} --body {{body}} [--label {{label}}] [--assignee {{login}}]` | gh help |
| Look at Actions runs | `gh run list`; `gh run view {{runId}}`; wait for one with `gh run watch {{runId}}` | gh help |
| Re-run a failed run | `gh run rerun {{runId}}` | gh help |
| Run a workflow manually | `gh workflow run {{workflow}} [--ref {{branch}}]` (the workflow needs a `workflow_dispatch` trigger) | gh help |
| Create a release | `gh release create {{tag}}`. Publishes publicly: confirm first | gh help |
| Merge a pull request | `gh pr merge {{number}}`. **Irreversible on the branch: confirm first** | gh help |
| Anything else in the web UI | `gh api {{endpoint}}` against the GitHub REST API | gh help |

## Azure DevOps

Needs the `azure-devops` extension for `az`. The Azure DevOps CLI doesn't support Azure DevOps Server; use the REST
API there.

| Recorded UI action | Equivalent | Checked against |
| --- | --- | --- |
| Boards > New work item | `az boards work-item create --title {{title}} --type {{type}} [--description …] [--assigned-to …] [--area …] [--iteration …] [--fields "Field=Value"]` | Learn: az boards |
| Open or edit a work item | `az boards work-item show --id {{id}}`; `az boards work-item update --id {{id}} [--state …] [--fields …]` | Learn: az boards |
| Repos > New pull request | `az repos pr create --repository {{repository}} --source-branch {{branch}} [--target-branch {{target}}] [--title …] [--work-items {{ids}}]` | Learn: Azure Repos pull requests |
| Pipelines > Run pipeline | `az pipelines run --name {{pipeline}} [--branch {{branch}}] [--parameters name=value] [--variables name=value]` | Learn: az pipelines |
| Look at a run | `az pipelines runs list [--pipeline-ids {{id}}] [--top 5]`; `az pipelines runs show --id {{runId}}` | Learn: az pipelines runs |
| Anything else | `az devops invoke` or the Azure DevOps REST API | Learn: Azure DevOps CLI |

## When the UI is the only way

Some maker-portal and admin-center pages have no CLI or API equivalent (for example some tenant settings or preview
features). Keep these as **Fragile (UI)** steps: name the page, the control's visible label, and the state that shows
it worked, and put a Verify check after them that doesn't rely on the screen when one exists.
