# Form & sitemap removal — validated Web API examples

Per [ADR 0013](../../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md): known-good,
copy-pasteable calls. Validated against a real environment (05 2026). The primary use case is
retiring obsolete components (e.g. Field Service tables) so re-parented lookup columns can be
deleted.

**Setup** (auth + shared invoker), assumed at the top of each snippet:

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

Placeholders: `new_table` = your table; `<formId>` / `<appModuleId>` = GUIDs; `<appUniqueName>` =
app module unique name.

---

## A. Pure REST — compose these directly

### A1. Delete a form

Resolve the form (optional — skip if you have the GUID), verify, delete, publish the table:

```http
GET    /api/data/v9.2/systemforms?$filter=objecttypecode eq 'new_table' and name eq 'My Form'&$select=formid,name,type
GET    /api/data/v9.2/systemforms(<formId>)?$select=name,type,objecttypecode
DELETE /api/data/v9.2/systemforms(<formId>)
POST   /api/data/v9.2/PublishXml      body: { "ParameterXml": "<importexportxml><entities><entity>new_table</entity></entities></importexportxml>" }
```
```powershell
Invoke-DataverseApi -Method GET    -Endpoint "systemforms($formId)?`$select=name,type,objecttypecode"
Invoke-DataverseApi -Method DELETE -Endpoint "systemforms($formId)"
Invoke-DataverseApi -Method POST   -Endpoint "PublishXml" `
    -Body @{ ParameterXml = "<importexportxml><entities><entity>new_table</entity></entities></importexportxml>" }
```

**Dependency error:** if the form is referenced (it's in an app module's form order, or it's the
table's only Main form), the DELETE is rejected. Remove those references first (see A2), then retry.

### A2. Remove a form from an app module — `RemoveAppComponents`

A form referenced by an app module can't be deleted. Discover the referencing app(s), then remove:

```http
GET  /api/data/v9.2/appmodulecomponents?$filter=objectid eq <formId>&$select=appmodulecomponentid,_appmoduleidunique_value
GET  /api/data/v9.2/appmodules?$filter=appmoduleidunique eq <aidUnique>&$select=appmoduleid,name,uniquename
POST /api/data/v9.2/RemoveAppComponents
```
```json
{
  "AppId": "<appModuleId>",
  "Components": [ { "@odata.type": "Microsoft.Dynamics.CRM.systemform", "formid": "<formId>" } ]
}
```
```powershell
Invoke-DataverseApi -Method POST -Endpoint "RemoveAppComponents" -Body @{
    AppId = $appModuleId
    Components = @( @{ "@odata.type" = "Microsoft.Dynamics.CRM.systemform"; formid = $formId } )
}
# then publish the app (A3)
```
(If you already know the app, resolve it directly: `GET appmodules?$filter=uniquename eq '<appUniqueName>'&$select=appmoduleid,name`.)

### A3. Publish a single app module — `PublishXml`

```http
POST /api/data/v9.2/PublishXml
```
```json
{ "ParameterXml": "<importexportxml><appmodules><appmodule><appModuleId></appmodule></appmodules></importexportxml>" }
```
Publishing one app at a time (rather than on every edit) avoids the *"Cannot start another
[Publish] because there is a previous [Publish] running"* error.

### A4. Remove a single sitemap sub-area

A single edit is safe to compose: read the sitemap once, remove the `<SubArea>`, PATCH, publish.

```http
GET   /api/data/v9.2/appmodules?$filter=uniquename eq '<appUniqueName>'&$expand=appmodulecomponents  (locate the sitemapid)
GET   /api/data/v9.2/sitemaps(<sitemapId>)?$select=sitemapxml
PATCH /api/data/v9.2/sitemaps(<sitemapId>)      body: { "sitemapxml": "<edited xml>" }   (header If-Match: *)
POST  /api/data/v9.2/PublishXml                 (A3)
```
Remove the node `//SubArea[@Id='<subAreaId>']` from its parent `<Group>` in the XML before the PATCH.

---

## B. Keep the composite helper — do NOT raw-compose these

Per ADR 0013 Rule 2 (wrap only what the agent can't safely re-derive each time), two operations stay
as composite helpers. Compose the boundary calls above, but use the helper for the logic:

### B1. `RemoveSubgrid` — FormXml DOM surgery

Removing a subgrid means parsing the form's `formxml`, finding the `<control>` by `id` **or** by its
`RelationshipName` parameter, removing the whole containing `<cell>` (and an emptied `<row>`),
re-serializing, PATCHing `systemforms(<formId>).formxml`, then publishing. The XML-walk and the
"remove the cell not just the control" rule are exactly the kind of fiddly, error-prone logic the
helper exists to hold. **Use the helper.**

### B2. `BatchSiteMapEdit` — multi-edit lost-update race

Dataverse serves `GET sitemapxml` from a cache that **lags** the PATCH write. Firing per-edit
add/remove calls in rapid succession makes each read a stale copy and the writes clobber one another
— only one edit survives. The safe pattern is **one** read → all edits in memory → **one** PATCH →
**one** publish. **Use the helper** for any change touching more than one sub-area; only single edits
(A4) are safe to compose.
