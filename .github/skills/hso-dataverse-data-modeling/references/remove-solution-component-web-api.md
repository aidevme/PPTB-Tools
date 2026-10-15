# Remove a component from a solution (composed, not wrapped)

Per [ADR 0013](../../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md): the skill
provides `AddTableToSolution` / `AddComponentToSolution` (both via the `AddSolutionComponent` action)
but **no remove counterpart** — removal is a thin Web API call, composed against the shared invoker,
not a new wrapper operation. This file is the validated, copy-pasteable pattern.

Use this to take an over-included component back out of an unmanaged solution — most commonly an OOB
table (`account`, `contact`) that got pulled in as a relationship dependency, or a stray column/view —
without deleting the component itself.

> ⚠️ **The `RemoveSolutionComponent` signature is NOT symmetric with `AddSolutionComponent`, and it
> varies between environments.** `AddSolutionComponent` takes `ComponentId` (a GUID). On the
> environment validated here (iksandbox, May 2026) `RemoveSolutionComponent` does **not** accept
> `ComponentId` — it rejects it with *"The parameter 'ComponentId' … is not a valid parameter for the
> operation 'RemoveSolutionComponent'"* — and instead exposes a `SolutionComponent` **entity-reference**
> parameter. **Always inspect the action signature first (Step 1) before building the body.**

## Setup (auth + shared invoker)

```powershell
# Run under Windows PowerShell 5.1 (powershell.exe), NOT pwsh 7 — when the token cache has expired,
# MSAL interactive sign-in only surfaces the browser under 5.1. See hso-shared-scripts/references/shared-modules.md.
$shared = ".claude\skills\hso-shared-scripts\scripts"
. "$shared\Dataverse-Auth.ps1"; . "$shared\Dataverse-WebApi.ps1"
$envUrl = "https://yourorg.crm.dynamics.com"
$token  = Get-DataverseToken -EnvironmentUrl $envUrl
```

## Step 1 — confirm the action's parameter names from `$metadata`

```powershell
$headers = @{ Authorization = "Bearer $token"; Accept = "application/xml" }
$meta = [xml](Invoke-RestMethod -Method Get -Uri "$envUrl/api/data/v9.2/`$metadata" -Headers $headers).OuterXml
($meta.GetElementsByTagName("Action") | Where-Object { $_.Name -eq "RemoveSolutionComponent" }).ChildNodes |
  Where-Object { $_.LocalName -eq "Parameter" } | ForEach-Object { "{0} : {1}" -f $_.Name, $_.Type }
```

Two signatures seen in the wild — branch on what this prints:

| Printed parameters | Use body form |
|--------------------|---------------|
| `ComponentId : Edm.Guid`, `ComponentType : Edm.Int32`, `SolutionUniqueName : Edm.String` | **Form A** (documented) |
| `SolutionComponent : mscrm.solutioncomponent`, `ComponentType : Edm.Int32`, `SolutionUniqueName : Edm.String` | **Form B** (validated here) |

## Step 0 (both forms) — find the component's `objectid` + `componenttype`

The `objectid` is the component's own id — for a **table** it is the entity `MetadataId`; for a column,
the attribute `MetadataId`; for a view, the `savedqueryid`; etc. Get it (and confirm it is in the
target solution) from the `solutioncomponents` set:

```powershell
$sol   = Invoke-DataverseApi -EnvironmentUrl $envUrl -Token $token -Method Get `
           -Endpoint "solutions?`$filter=uniquename eq 'MySolution'&`$select=solutionid"
$solId = $sol.value[0].solutionid

# Example: the 'contact' table's component row in this solution
$contactMetadataId = (Invoke-DataverseApi -EnvironmentUrl $envUrl -Token $token -Method Get `
    -Endpoint "EntityDefinitions(LogicalName='contact')?`$select=MetadataId").MetadataId
$sc = Invoke-DataverseApi -EnvironmentUrl $envUrl -Token $token -Method Get `
    -Endpoint "solutioncomponents?`$filter=_solutionid_value eq $solId and objectid eq $contactMetadataId&`$select=componenttype"
$componentType = [int]$sc.value[0].componenttype   # 1 = Entity
```

## Step 2A — body when the signature exposes `ComponentId` (documented form)

```powershell
$body = @{ ComponentId = $contactMetadataId; ComponentType = $componentType; SolutionUniqueName = "MySolution" }
Invoke-DataverseApi -EnvironmentUrl $envUrl -Token $token -Method Post -Endpoint "RemoveSolutionComponent" -Body $body
```

## Step 2B — body when the signature exposes `SolutionComponent` (validated, iksandbox May 2026)

**Counterintuitive but validated:** pass a `solutioncomponent` entity reference, and put the component's
**`objectid` value into the `solutioncomponentid` key slot.** The action uses the value in that key slot
as the *objectid* to locate the component within the solution (paired with `ComponentType`). Passing the
real `solutioncomponent` row PK there fails with *"Cannot find solution component … in solution"*; passing
only `objectid` fails with *"EdmEntityObject … should have the key property value set."*

```powershell
$body = @{
  SolutionComponent  = @{ "@odata.type" = "Microsoft.Dynamics.CRM.solutioncomponent"
                          "solutioncomponentid" = $contactMetadataId }   # objectid value goes in the key slot
  ComponentType      = $componentType
  SolutionUniqueName = "MySolution"
}
Invoke-DataverseApi -EnvironmentUrl $envUrl -Token $token -Method Post -Endpoint "RemoveSolutionComponent" -Body $body
```

## Verify

```powershell
$comps = Invoke-DataverseApi -EnvironmentUrl $envUrl -Token $token -Method Get `
    -Endpoint "solutioncomponents?`$filter=_solutionid_value eq $solId&`$select=componenttype,objectid"
"remaining components: $((@($comps.value)).Count)"
```

## Common `componenttype` codes

| Code | Component | Code | Component |
|------|-----------|------|-----------|
| 1 | Entity (table) | 26 | SavedQuery (view) |
| 2 | Attribute (column) | 59 | SavedQueryVisualization (chart) |
| 9 | OptionSet (global choice) | 60 | SystemForm (form) |
| 10 | EntityRelationship | 61 | WebResource |

## Gotchas

- **Removing ≠ deleting.** `RemoveSolutionComponent` only detaches the component from the solution; the
  component still exists in the system. (To delete the component itself, use the relevant DELETE —
  e.g. `DELETE EntityDefinitions(LogicalName='…')` for a table.)
- **OOB-table cleanup.** Deleting a custom table that had a lookup to `account`/`contact` does **not**
  remove those OOB tables from the solution — they were added as separate `behavior=1` (shell/dependency)
  components and must be removed explicitly with this pattern.
- **The "cannot find … in solution" error under Form B is misleading** — it means the value you put in
  the key slot was treated as an `objectid` and no component with that `objectid` + `ComponentType` exists
  in the solution. Re-check that you passed the component's `objectid` (Step 0), not the `solutioncomponent`
  row PK.
- **Auth / PowerShell version:** if `Get-DataverseToken` hangs with no browser prompt, you are in pwsh 7;
  re-run under `powershell.exe` (Windows PowerShell 5.1).

## See also

- [`column-dependencies-web-api.md`](column-dependencies-web-api.md) — what blocks a *delete* (read-only).
- SKILL.md §1.2–§1.3 — `AddTableToSolution` / `AddComponentToSolution` (the add side; note the `ComponentId`
  asymmetry called out above).
