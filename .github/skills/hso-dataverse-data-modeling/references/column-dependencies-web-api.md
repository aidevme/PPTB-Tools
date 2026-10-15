# Query a column's dependencies (why it won't delete) — validated Web API example

Per [ADR 0013](../../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md): known-good,
copy-pasteable, **read-only** calls. Validated against a real environment (05 2026). This is the
answer to the opaque *"cannot be deleted because it is referenced by N other components"* error from
`DeleteColumn` — it names which components.

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

Two steps: resolve the column's `MetadataId`, then ask `RetrieveDependenciesForDelete` (ComponentType
**2** = Attribute).

```http
GET /api/data/v9.2/EntityDefinitions(LogicalName='new_table')/Attributes(LogicalName='new_lookup_id')?$select=MetadataId,LogicalName,AttributeType
GET /api/data/v9.2/RetrieveDependenciesForDelete(ObjectId=<metadataId>,ComponentType=2)
```
```powershell
$attr = Invoke-DataverseApi -Method GET `
    -Endpoint "EntityDefinitions(LogicalName='new_table')/Attributes(LogicalName='new_lookup_id')?`$select=MetadataId,AttributeType"
$dep = Invoke-DataverseApi -Method GET `
    -Endpoint "RetrieveDependenciesForDelete(ObjectId=$($attr.MetadataId),ComponentType=2)"
$dep.value   # each: dependentcomponenttype (int), dependentcomponentobjectid (guid)
```
The GUID is passed **unquoted / unbraced** inside the function URL.

**Interpreting `dependentcomponenttype`** (the common ones):

| Code | Component | Resolve the friendly name via |
|------|-----------|-------------------------------|
| 26 | SavedQuery (View) | `GET savedqueries(<id>)?$select=name,querytype,returnedtypecode` |
| 59 | SavedQueryVisualization (Chart) | `GET savedqueryvisualizations(<id>)?$select=name,primaryentitytypecode` |
| 60 | SystemForm (Form) | `GET systemforms(<id>)?$select=name,type,objecttypecode` |
| 1 / 2 / 9 / 10 | Entity / Attribute / OptionSet / EntityRelationship | (usually self-evident from context) |
| 14 | EntityKey (alternate key) | `GET EntityDefinitions(LogicalName='new_table')/Keys?$select=SchemaName,MetadataId,KeyAttributes,EntityKeyIndexStatus` then match the dependent `objectid` to a key's `MetadataId` — there is no top-level entityset for keys, so you must go through the table's `/Keys`. |
| 62 / 70 / 90 / 92 / 150 | SiteMap / FieldSecurityProfile / PluginType / SDKMessageProcessingStep / RibbonCustomization | — |

Empty `value` ⇒ no dependencies ⇒ the column is safe to delete — **except the primary name column,
which the platform never allows you to delete regardless of dependencies** (this check does not apply
to it). Otherwise, remove the column from each listed component (e.g. via `hso-dataverse-ui-config`
form/view edits), then delete it.

**`QueryColumnDependencies` is the read-only skill operation** — the non-destructive entry point to this
exact preflight. Use it to answer "what references this column / what would block its delete?" *without*
deleting (or hand-rolling the Web API call). It resolves each blocker to a friendly name — forms, views,
charts, **and alternate keys (componenttype 14)** — and flags the primary name column:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation QueryColumnDependencies -EnvironmentUrl $EnvironmentUrl `
    -TableName "new_table" -ColumnName "new_lookup_id"
```

**`DeleteColumn` is the destructive skill operation** (dispatches to the guarded `Remove-DataverseColumn`).
It runs the *same* preflight before deleting: it refuses and lists the blocking forms/views/keys by name if
any dependencies remain, and refuses outright on the primary name column. Pass `-Force` to bypass the
dependency refusal (the primary-column guard is absolute). This reference remains the manual / copy-paste
form of the check — handy for components other than columns (see Raw mode below).

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data-modeling/scripts/Invoke-DataverseMetadataOperation.ps1" `
    -Operation DeleteColumn -EnvironmentUrl $EnvironmentUrl `
    -TableName "new_table" -ColumnName "new_lookup_id"   # add -Force to bypass the dependency refusal
```

**Raw mode** (any component, not just a column): pass the component's own `MetadataId`/objectid and
its numeric component type, e.g. a chart is `ComponentType=59`.
