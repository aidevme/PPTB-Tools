# Field Security Profiles (column-level security) — validated Web API examples

Per [ADR 0013](../../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md): known-good,
copy-pasteable calls. Adapt the example; don't compose from scratch. Validated against a real
environment (05 2026).

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

Placeholders: `new_clientref` / `new_ssn_text` = your secured table/column; `<YourSolutionUniqueName>`;
`<profileId>` / `<teamId>` = resolved GUIDs. Access rights: **0 = Not Allowed, 4 = Allowed**
(`canreadunmasked`: 0 / 1 = One Record / 3 = All Records, for data masking).

> **HSO rule (security SOP):** assign Field Security Profiles to **teams, not users.** Profiles and
> their `fieldpermission` rows **travel in a solution**; team/user *assignments* do **not** — they
> are per-environment config and must be re-applied after each import.

---

## Prerequisite: secure the column first

A `fieldpermission` against a non-secured column fails. Secure the target column via the skill's
existing `hso-dataverse-data-modeling` **`UpdateColumn -IsSecured $true`** operation (existing
wrapper — leave it as-is per the hybrid). Only then grant access below.

---

## 1. Create a Field Security Profile

```http
POST /api/data/v9.2/fieldsecurityprofiles
Content-Type: application/json; charset=utf-8
MSCRM.SolutionUniqueName: <YourSolutionUniqueName>
Prefer: return=representation
```
```json
{ "name": "PHI Columns", "description": "Grants Create/Read/Update on PHI columns to the care team." }
```
```powershell
$headers = Get-DataverseHeaders -Token $token -ReturnRepresentation $true -SolutionName "<YourSolutionUniqueName>"
$resp = Invoke-DataverseApi -Method POST -Endpoint "fieldsecurityprofiles" `
    -Body @{ name = "PHI Columns"; description = "..." } -Headers $headers -ReturnRepresentation $true
$profileId = $resp.fieldsecurityprofileid
```

**Find by name** (idempotency check before create, and to resolve an id):

```http
GET /api/data/v9.2/fieldsecurityprofiles?$filter=name eq 'PHI Columns'&$select=fieldsecurityprofileid,name,description
```
Escape the name for OData: double single-quotes, then URL-encode (`[uri]::EscapeDataString($name.Replace("'","''"))`).

---

## 2. Grant a column permission — `fieldpermission`

The navigation property that binds a `fieldpermission` to its profile is not always the attribute
logical name — **resolve it from relationship metadata** (cache it), don't hard-code:

```http
GET /api/data/v9.2/RelationshipDefinitions/Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata?$select=SchemaName,ReferencingEntityNavigationPropertyName&$filter=ReferencedEntity eq 'fieldsecurityprofile' and ReferencingEntity eq 'fieldpermission'
```
Use `ReferencingEntityNavigationPropertyName` from the result (conventional fallback:
`FieldSecurityProfileId`). Then create the row:

```http
POST /api/data/v9.2/fieldpermissions
Content-Type: application/json; charset=utf-8
MSCRM.SolutionUniqueName: <YourSolutionUniqueName>
Prefer: return=representation
```
```json
{
  "entityname": "new_clientref",
  "attributelogicalname": "new_ssn_text",
  "cancreate": 4,
  "canread": 4,
  "canupdate": 4,
  "FieldSecurityProfileId@odata.bind": "/fieldsecurityprofiles(<profileId>)"
}
```
```powershell
$navProp = "FieldSecurityProfileId"   # resolved from the metadata call above
$body = @{
    entityname              = "new_clientref"
    attributelogicalname    = "new_ssn_text"
    cancreate = 4; canread = 4; canupdate = 4
    "$navProp@odata.bind"   = "/fieldsecurityprofiles($profileId)"
    # canreadunmasked = 1   # optional: enable data masking
}
$headers = Get-DataverseHeaders -Token $token -ReturnRepresentation $true -SolutionName "<YourSolutionUniqueName>"
Invoke-DataverseApi -Method POST -Endpoint "fieldpermissions" -Body $body -Headers $headers -ReturnRepresentation $true
```

If this fails, the column is almost certainly not secured yet — see the prerequisite.

---

## 3. Assign the profile to a team — `teamprofiles_association`

Resolve the team, then associate via `$ref`:

```http
GET /api/data/v9.2/teams?$filter=name eq 'Care Team'&$select=teamid,name,teamtype

POST /api/data/v9.2/fieldsecurityprofiles(<profileId>)/teamprofiles_association/$ref
Content-Type: application/json; charset=utf-8
```
```json
{ "@odata.id": "https://yourorg.crm.dynamics.com/api/data/v9.2/teams(<teamId>)" }
```
```powershell
$base = $EnvironmentUrl.TrimEnd('/')
Invoke-DataverseApi -Method POST -Endpoint "fieldsecurityprofiles($profileId)/teamprofiles_association/`$ref" `
    -Body @{ "@odata.id" = "$base/api/data/v9.2/teams($teamId)" }
```

**Unassign** (note: assignments don't travel in solutions, so this is environment cleanup):

```http
DELETE /api/data/v9.2/fieldsecurityprofiles(<profileId>)/teamprofiles_association(<teamId>)/$ref
```

---

## 4. Inspect a profile (permissions + teams)

```http
GET /api/data/v9.2/fieldsecurityprofiles(<profileId>)?$select=fieldsecurityprofileid,name,description
GET /api/data/v9.2/fieldpermissions?$filter=_fieldsecurityprofileid_value eq <profileId>&$select=entityname,attributelogicalname,cancreate,canread,canupdate&$orderby=entityname,attributelogicalname
GET /api/data/v9.2/fieldsecurityprofiles(<profileId>)/teamprofiles_association?$select=teamid,name
```

## 5. Delete a profile

```http
DELETE /api/data/v9.2/fieldsecurityprofiles(<profileId>)
```
The profile's `fieldpermission` rows go with it. Team assignments are environment config; they do
not block the delete.
