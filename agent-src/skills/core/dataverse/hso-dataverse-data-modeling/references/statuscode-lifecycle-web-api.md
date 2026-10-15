# Statuscode / statecode lifecycle — validated Web API examples

Per [ADR 0013](../../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md): these are
**known-good, copy-pasteable** Web API calls for the custom-status lifecycle operations. Adapt the
example — do not compose these from scratch. Every call here was validated against a real
environment (05 2026) across multiple custom tables.

All calls assume auth is already resolved and the shared invoker is loaded:

```powershell
# the hso-shared-scripts modules are copied to .claude/skills/hso-shared-scripts/scripts in a project,
# and the session's working directory is the repo root — so dot-source by this repo-root-relative path.
# Use the $PSScriptRoot form ("..\..\hso-shared-scripts\scripts") ONLY for a script living inside a
# skill folder; it does NOT work for an ad-hoc/temp script. For the resolver, the execution pattern
# (write a temp .ps1 and run with -File; never pipe powershell.exe output into a PS cmdlet from Bash),
# and the function signatures, see hso-shared-scripts/references/shared-modules.md.
$shared = ".claude\skills\hso-shared-scripts\scripts"
. "$shared\Dataverse-Auth.ps1"; . "$shared\Dataverse-WebApi.ps1"
$token = Get-DataverseToken -EnvironmentUrl $EnvironmentUrl   # sets script-scope token + env
```

Placeholders: `new_workitem` = your table; `<YourSolutionUniqueName>` = the unsegmented solution;
custom statuscode values carry **your publisher's option-value prefix** (shown here as `97531` →
values `975310000+`). Platform values Active=1 / Inactive=2 are unprefixed and platform-owned.

> **The one rule that explains all three operations below:** per-option lifecycle changes
> (`IsHidden`, a state's `DefaultStatus`, deleting a value) go through Web API **actions**, never an
> attribute/option-set metadata **PATCH**. A `PUT`/`PATCH` of the `statecode`/`statuscode`
> `*AttributeMetadata` returns `2xx` but **silently no-ops** for option-level changes — only
> `OptionSetMetadataBase` scalar properties update that way, never the options.

---

## Prerequisite: add a custom status reason (existing operation)

Adding a custom statuscode value is already covered by the skill's `AddStatusValue` operation (or the
`InsertStatusValue` action). Values carry the publisher prefix (`975310000+`); never bare integers
like `10`/`20` (the spec's `(10)` notation is ordering shorthand, not the literal value).

> ⚠️ **Adding more than one custom status in a session — pass EXPLICIT prefixed values**
> (`975310001`, `975310002`, …). **Do not rely on auto-generation for multi-add.** Auto-gen derives
> the next value from a metadata read that **lags** the previous insert (read-after-write cache — the
> same class of lag as the sitemap race), so back-to-back auto-adds collide on the same value (HTTP
> 400) and can leave a phantom duplicate you then have to `DeleteOptionValue`. Explicit values avoid
> it entirely.

**State-mapping convention:** terminal / end-of-life labels (Done, Cancelled, Retired) bind to the
**Inactive** state (`1`); in-flight labels (Draft, In Review, Active) bind to the **Active** state (`0`).

---

## 1. Hide a status reason — `UpdateOptionValue` action

The supported way to **retire** the platform Active(1)/Inactive(2) reasons (and any custom value)
without deleting them. A hidden value disappears from dropdowns for new/updated records but stays
valid on existing records and in queries. `IsHidden` is a real `Edm.Boolean` parameter on
`UpdateOptionValue`, omitted from the doc examples but present in the action.

```http
POST /api/data/v9.2/UpdateOptionValue
Content-Type: application/json; charset=utf-8
```
```json
{
  "EntityLogicalName": "new_workitem",
  "AttributeLogicalName": "statuscode",
  "Value": 1,
  "IsHidden": true,
  "MergeLabels": true,
  "SolutionUniqueName": "<YourSolutionUniqueName>"
}
```
```powershell
$body = @{
    EntityLogicalName    = "new_workitem"
    AttributeLogicalName = "statuscode"
    Value                = 1
    IsHidden             = $true
    MergeLabels          = $true
    SolutionUniqueName   = "<YourSolutionUniqueName>"
}
Invoke-DataverseApi -Method POST -Endpoint "UpdateOptionValue" -Body $body
```

For the **local statuscode set you must address it by `EntityLogicalName` + `AttributeLogicalName`**
— there is no `OptionSetName` for a status set. **Publish the table** afterward for it to take
effect in apps.

**Verify (read-back gotcha):** `IsHidden` comes back as a primitive bool under `$expand=OptionSet`,
but is **absent** under `$expand=OptionSet($select=Options)`. Use the full expand:

```http
GET /api/data/v9.2/EntityDefinitions(LogicalName='new_workitem')/Attributes(LogicalName='statuscode')/Microsoft.Dynamics.CRM.StatusAttributeMetadata?$expand=OptionSet
```

Ready-to-run verify (lists each option with State / Hidden / Label). Note `IsHidden` is read as a
**primitive bool** here — do **not** use `.Value`:

```powershell
$attr = Invoke-DataverseApi -Method GET -Endpoint "EntityDefinitions(LogicalName='new_workitem')/Attributes(LogicalName='statuscode')/Microsoft.Dynamics.CRM.StatusAttributeMetadata?`$expand=OptionSet"
$attr.OptionSet.Options | Sort-Object Value | ForEach-Object {
    [pscustomobject]@{
        Value  = $_.Value
        State  = $_.State                          # 0 = Active, 1 = Inactive
        Hidden = [bool]$_.IsHidden                  # primitive bool under full $expand (blank under $select=Options)
        Label  = $_.Label.UserLocalizedLabel.Label
    }
} | Format-Table -AutoSize
```

---

## 2. Repoint a state's default status — `UpdateStateValue` action

After hiding Active(1)/Inactive(2), new records should default to a meaningful custom status. This
is also the **prerequisite for deleting** a platform default (see §3). `DefaultStatusCode` is the
supported parameter; a PATCH of the statecode `StateAttributeMetadata` is a silent no-op.

```http
POST /api/data/v9.2/UpdateStateValue
Content-Type: application/json; charset=utf-8
MSCRM.SolutionUniqueName: <YourSolutionUniqueName>
```
```json
{
  "EntityLogicalName": "new_workitem",
  "AttributeLogicalName": "statecode",
  "Value": 0,
  "DefaultStatusCode": 975310001,
  "MergeLabels": true
}
```
```powershell
$headers = Get-DataverseHeaders -Token $token -SolutionName "<YourSolutionUniqueName>"
$body = @{
    EntityLogicalName    = "new_workitem"
    AttributeLogicalName = "statecode"
    Value                = 0           # 0 = Active state, 1 = Inactive state
    DefaultStatusCode    = 975310001   # a custom statuscode bound to that state
    MergeLabels          = $true
}
Invoke-DataverseApi -Method POST -Endpoint "UpdateStateValue" -Body $body -Headers $headers
```

---

## 3. Delete a status reason — `DeleteOptionValue` action

```http
POST /api/data/v9.2/DeleteOptionValue
Content-Type: application/json; charset=utf-8
```
```json
{
  "EntityLogicalName": "new_workitem",
  "AttributeLogicalName": "statuscode",
  "Value": 975310099,
  "SolutionUniqueName": "<YourSolutionUniqueName>"
}
```
```powershell
$body = @{
    EntityLogicalName    = "new_workitem"
    AttributeLogicalName = "statuscode"
    Value                = 975310099
    SolutionUniqueName   = "<YourSolutionUniqueName>"
}
Invoke-DataverseApi -Method POST -Endpoint "DeleteOptionValue" -Body $body
```

**Two traps, both seen live:**

- The **global-choice** `DeleteOptionValue` path (`OptionSetName`) **cannot** touch a status set —
  it returns `0x80048403` (*"An OptionSet with IsGlobal='False' and OptionSetType='Status' cannot be
  retrieved through this SDK method"*). Always use `EntityLogicalName` + `AttributeLogicalName`.
- A value that is still a state's **Default Status** cannot be deleted — `0x80044341` (*"Default
  Status options cannot be deleted"*). Repoint the default first (§2), or just hide it (§1).

---

## Recommended pattern — retire the generic Active/Inactive in favour of a custom lifecycle

1. Add the custom statuscode values (prerequisite above), prefixed (`975310000+`).
2. `UpdateStateValue` / `DefaultStatusCode` → repoint each state's default to a custom value (§2).
3. `UpdateOptionValue` / `IsHidden=true` on values **1** and **2** (§1) — hide, don't delete.
4. **Publish** the table.

Hiding is preferred over deleting: reversible, standard, and it avoids the `0x80044341` /
`0x80048403` traps entirely. Delete (§3) only when you specifically need the value gone, and only
after step 2.
