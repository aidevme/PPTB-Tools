# Delete a system chart — validated Web API example

Per [ADR 0013](../../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md): known-good,
copy-pasteable call. Validated against a real environment (05 2026).

**Setup** (auth + shared invoker):

```powershell
# the hso-shared-scripts modules are copied to .claude/skills/hso-shared-scripts/scripts in a project,
# and the session's working directory is the repo root — so dot-source by this repo-root-relative path.
# Use the $PSScriptRoot form ("..\..\hso-shared-scripts\scripts") ONLY for a script living inside a
# skill folder; it does NOT work for an ad-hoc/temp script. Robust multi-location resolver: see
# hso-shared-scripts/references/shared-modules.md.
$shared = ".claude\skills\hso-shared-scripts\scripts"
. "$shared\Dataverse-Auth.ps1"; . "$shared\Dataverse-WebApi.ps1"
$token = Get-DataverseToken -EnvironmentUrl $EnvironmentUrl
```

A system chart is a `savedqueryvisualization`. Verify it exists (graceful 404), then delete:

```http
GET    /api/data/v9.2/savedqueryvisualizations(<chartId>)?$select=name,primaryentitytypecode
DELETE /api/data/v9.2/savedqueryvisualizations(<chartId>)
```
```powershell
$chartId = ($ChartId -replace '[{}]','')
# 1. Verify (and report what you're about to delete)
$chart = Invoke-DataverseApi -Method GET -Endpoint "savedqueryvisualizations($chartId)?`$select=name,primaryentitytypecode"
# 2. Delete
Invoke-DataverseApi -Method DELETE -Endpoint "savedqueryvisualizations($chartId)"
```

**No publish step.** A chart delete is immediate server-side — there is no unpublished layer to
flush, so do **not** call `PublishXml` for it.

**Gotchas:**
- If the GET returns 404 (`Does Not Exist` / `Could not find`), the chart is already gone — treat as
  a no-op, nothing to delete.
- If the DELETE is rejected for **dependencies**, the chart is still referenced (e.g. a dashboard
  cell points at it). Remove those references first, then retry.
