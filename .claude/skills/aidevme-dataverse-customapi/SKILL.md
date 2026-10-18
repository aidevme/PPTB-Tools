---
name: aidevme-dataverse-customapi
metadata:
  layer: atomic
  scope: core
description: |
  Create, update, query, and delete Dataverse Custom APIs (metadata + request parameters + response properties) via the Dataverse Web API. Use when:
  (1) User asks to "create a Custom API" or "register a Custom API" in Dataverse
  (2) User has plugin code implementing IPlugin for a custom message
  (3) User wants to set up Custom API metadata (request parameters, response properties)
  (4) User mentions Custom API input/output parameters
  (5) User wants to update, query, or delete an existing Custom API
  Uses PowerShell scripts with Web API for all operations. Always deploy plugin assembly FIRST using the hso-plugin-development skill.
---

# Dataverse Custom API

Create and manage Dataverse Custom APIs (metadata, request parameters, response properties) using the Web API via PowerShell scripts.

## Slice Consumption Contract (executor side of the architect→builder pipeline)

**Authority:** [`slice-consumption-contract-best-practices.md`](../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md) — read before building any slice inside the pipeline. That SOP is the **canonical, executor-side contract** for [ADR 0018](../../../agent/wiki/decisions/0018-agentic-delivery-architect-builder-pipeline.md)'s architect→builder pipeline (the five rules, single-writer, reviewable-unit, anti-mis-attribution). The summary here is a labeled pointer, not a substitute.

When the architect routes a slice to this skill you are handed **the spec + its `spec.json` sidecar + a target slice `id`**. Build **exactly that slice's `touches`** and nothing more; trust and verify — don't rebuild — your `blocked_by` slices; honor every recorded design decision (binding type, `IsFunction`, parameter shapes the spec set); **read back against the slice's `acceptance`, not against an SOP rule the spec never invoked**; and end at the **unmanaged solution** named in `spec.json` (never export-as-managed or deploy).

| When a slice's `touches` include… | What this skill owns | Read-back against `acceptance` |
|---|---|---|
| a **Custom API** (function or action, with request parameters / response properties) | the `customapi` metadata row + its `customapirequestparameters` + `customapiresponseproperties` — **not** the plugin that *implements* the message (that is `hso-plugin-development`'s code-slice half; deploy the assembly first) | `customapis` (`isfunction`, `bindingtype`, `boundentitylogicalname`, `allowedcustomprocessingsteptype`), `customapirequestparameters`, `customapiresponseproperties` |

> All executor skills share the **same** [Slice Consumption Contract](../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md); the plugin that implements the message is the code-slice half of [`hso-plugin-development`](../hso-plugin-development/SKILL.md).

## Authority

**Authority for Custom API design, security, performance, and ALM — read before authoring or modifying any Custom API:**

> **[`shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md`](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md)**

Its guidance takes priority over anything in this SKILL.md. When making any Custom API design decision (binding type, IsFunction, AllowedCustomProcessingStepType, IsPrivate, ExecutePrivilegeName, parameter type choice, response envelope, error handling), consult the SOP first and cite the relevant section in the response.

Sections most relevant to this skill's job:
- [Section 2 — Naming conventions](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md#2-naming-conventions) — uniquename PascalCase rules, parameter and response-property naming, immutable post-publish
- [Section 3 — Custom API metadata model](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md#3-the-custom-api-metadata-model) — what's mutable vs immutable across customapi/parameter/property
- [Section 4 — Binding type](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md#4-binding-type--global-entity-entitycollection) — Global / Entity / EntityCollection decision and URL-shape consequences
- [Section 5 — IsFunction (GET) vs Action (POST)](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md#5-isfunction-get-vs-action-post) — HSO default `IsFunction=false`
- [Section 6 — AllowedCustomProcessingStepType](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md#6-allowedcustomprocessingsteptype) — None / AsyncOnly / SyncAndAsync; needed for "When an action is performed" trigger
- [Section 7 — IsPrivate](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md#7-isprivate) — default privacy strategy and per-environment overrides
- [Section 9 — Request parameters](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md#9-request-parameters) — type table, IsOptional immutability, workflow type restrictions
- [Section 10 — Response properties](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md#10-response-properties) — HSO standard envelope (Success / Message / *Count / RecordId)
- [Section 21 — Versioning, deprecation, immutability](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md#21-versioning-deprecation-and-immutability) — what breaks callers and how to ship v2
- [Section 22 — Solution layering and ALM](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md#22-solution-layering-and-alm) — split CustomAPIs and Plugins solutions; iscustomizable=false in shipped managed solutions
- [Section 26 — Pre-merge checklist](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md#26-pre-merge-and-pre-deploy-checklist) — walk before approving any change

When the SOP and this SKILL.md appear to conflict, **the SOP wins**.

**In a multi-language environment**, the [Localization SOP §5.1](../../../shared/dv/agent/wiki/sop/model-driven-apps/localization-best-practices.md#51-plug-ins-and-custom-apis) is the authority for localizing the API's error messages (per-language web-resource store, initiating user's `uilanguageid`, base-language fallback — override `DV-MODEL-DRIVEN-APPS-004`, `PROPOSED`), and its [§3](../../../shared/dv/agent/wiki/sop/model-driven-apps/localization-best-practices.md#3-label-and-metadata-translation--mechanics-and-alm) covers translating the API's display-name/parameter labels (`SetLocLabels` / `CrmTranslations`).

> **HSO ruling — ExecutePrivilegeName is NOT required (Ivan Kurtev, 2026-06-13).** Do **not** set `executeprivilegename` on Custom APIs and do **not** treat its absence as a gap, finding, or open design decision. Table privileges are the gate; the platform has no real per-API privilege model. A dedicated execute privilege would only be worthwhile if we could *create and assign a purpose-built privilege* for the API — which Dataverse does not support (Microsoft does not mint custom-named privileges). Leave `executeprivilegename` empty unless an existing built-in privilege is a genuinely better fit than the bound table's privileges. Grills and reviews must not raise it.

**Prerequisites:**
- Plugin code implementing the Custom API
- Plugin assembly deployed to Dataverse (use `hso-plugin-development` skill FIRST)
- Unique name format: `{prefix}_PascalCaseActionName` (e.g. `hso_RegenerateAgreementBookingDates`) — see SOP Section 2
- **Naming conventions**: Use the `hso-dataverse-naming-conventions` skill for Custom API unique name format and parameter naming standards

## Authentication

**Custom API changes are critical operations.** Authentication mode is resolved automatically from settings when this skill modifies your Dataverse environment.

When browser sign-in is used:
1. **First call**: A browser window opens for Office 365 login
2. You authenticate with your credentials
3. **Token is cached** for subsequent operations (~1 hour validity)
4. **Subsequent calls**: Use cached token automatically - no browser popup

**Token caching details:**
- Cache location: `%TEMP%\DataverseAuthCache_<environment-hash>.json`
- Token validity: ~1 hour (checked with 5-minute buffer)
- Cache is per-environment (different environments have separate caches)

## Operations Summary

| Operation | Description |
|-----------|-------------|
| **CreateCustomAPI** | Deep insert - creates API + request parameters + response properties in ONE call |
| **UpdateCustomAPI** | Update mutable fields (displayname, description, isprivate, plugin binding) |
| **QueryCustomAPI** | Query a Custom API with expanded parameters, properties, and plugin type |
| **QueryPluginType** | Find a plugin type by class name (to get the GUID) |
| **DeleteCustomAPI** | Delete a Custom API (cascades to parameters/properties) |
| **AddRequestParameter** | Add a request parameter to an existing Custom API |
| **AddResponseProperty** | Add a response property to an existing Custom API |
| **DeleteRequestParameter** | Remove a request parameter from a Custom API |
| **DeleteResponseProperty** | Remove a response property from a Custom API |

---

## Workflow

### Step 1: Extract Information from Plugin Code

Read the plugin to extract:
- Custom API name (from `context.MessageName`)
- Input parameters (from `context.InputParameters`)
- Output parameters (from `context.OutputParameters`)

> **GOTCHA — `SharedVariables` do NOT survive the Custom API SYSTEM-service context change (skill-gap #15).** A Custom API executes in its own **SYSTEM service** context, so a guard or handshake that stashes a flag in `IPluginExecutionContext.SharedVariables` on an outer operation **cannot read it back** from inside the API plugin — the variable is gone across the context boundary, and the guard silently no-ops. When a downstream plugin must detect "am I running inside Custom API message X?", **walk the `ParentContext` chain and compare `MessageName`** rather than relying on a SharedVariables flag. This was an env-only defect found via live read-back — unit tests pass because they never cross the real context boundary; only a live read-back reveals it. (Distinct from the documented rule that you can't pass *secure/unsecure configuration* to a Custom API plugin — this is about runtime context propagation.)

### Step 2: Deploy Plugin Assembly

Use the `deploy-plugin` skill to deploy the plugin assembly to Dataverse.

### Step 3: Verify Plugin Type Exists

```powershell
powershell -ExecutionPolicy Bypass -File "claude-code/skills/aidevme-dataverse-customapi/scripts/Invoke-DataverseCustomAPIOperation.ps1" `
    -Operation QueryPluginType `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -PluginTypeName "YourNamespace.Plugins.YourPluginClass"
```

### Step 4: Create Custom API (Single Deep Insert)

This creates the Custom API, all request parameters, and all response properties in ONE API call:

```powershell
powershell -ExecutionPolicy Bypass -File "claude-code/skills/aidevme-dataverse-customapi/scripts/Invoke-DataverseCustomAPIOperation.ps1" -Operation CreateCustomAPI -EnvironmentUrl "https://yourorg.crm.dynamics.com" -APIUniqueName "hso_ActionName" -APIDisplayName "Action Display Name" -APIDescription "Description of what the API does" -BindingType 0 -AllowedCustomProcessingStepType 0 -PluginTypeName "YourNamespace.Plugins.YourPluginClass" -RequestParametersJson '[{"UniqueName":"Target","DisplayName":"Target","Description":"Target record","Type":5,"IsOptional":false,"LogicalEntityName":"account"}]' -ResponsePropertiesJson '[{"UniqueName":"Success","DisplayName":"Success","Description":"Whether the operation succeeded","Type":0},{"UniqueName":"Message","DisplayName":"Message","Description":"Result message","Type":10}]' -SolutionName "YourSolutionName"
```

**Notes:**
- Use `-File` invocation (not `-Command`). JSON strings pass through cleanly without escaping.
- `-IsFunction` and `-IsPrivate` are switches: omit them for false (default), add the flag for true.
- For entity-bound APIs, add `-BindingType 1 -BoundEntityLogicalName "hso_tablename"`.
- The entire command must be on a **single line** (no backtick line continuation through bash).

### Step 5: Verify

```powershell
powershell -ExecutionPolicy Bypass -File "claude-code/skills/aidevme-dataverse-customapi/scripts/Invoke-DataverseCustomAPIOperation.ps1" `
    -Operation QueryCustomAPI `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -APIUniqueName "hso_ActionName"
```

Confirm the output shows:
- Plugin type is linked (not `(none)`)
- All request parameters are present
- All response properties are present

---

## Detailed Operation Reference

### 1. CreateCustomAPI

Creates a Custom API with all parameters and properties in a single deep-insert POST.

**Parameters:**

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| APIUniqueName | Yes | - | Unique name (e.g., `hso_SubmitForApproval`) |
| APIDisplayName | No | Same as unique name | Display name shown in UI |
| APIDescription | No | - | Description of the API |
| BindingType | No | 0 | 0=Global, 1=Entity, 2=EntityCollection |
| BoundEntityLogicalName | If bound | - | Required when BindingType is 1 or 2 |
| IsFunction | No | false (switch) | Default false (Action/POST). Set true (GET) ONLY when the op is genuinely read-only, inputs fit a URL, no Power Automate consumer is planned, and you need GET ergonomics — and it is immutable. Digest of SOP Section 5; read it before choosing. |
| IsPrivate | No | false (switch) | Add flag to hide from Power Automate. Omit to show. |
| AllowedCustomProcessingStepType | No | 0 | 0=None, 1=Async Only, 2=Sync and Async |
| PluginTypeName | No | - | Full class name of the plugin (auto-resolved to GUID) |
| RequestParametersJson | No | - | JSON array of request parameters |
| ResponsePropertiesJson | No | - | JSON array of response properties |
| SolutionName | No | - | Solution to add the API to |

**Request Parameter JSON Format:**
```json
[
  {
    "UniqueName": "Target",
    "DisplayName": "Target Record",
    "Description": "The record to process",
    "Type": 5,
    "IsOptional": false,
    "LogicalEntityName": "account"
  }
]
```

**Response Property JSON Format:**
```json
[
  {
    "UniqueName": "Success",
    "DisplayName": "Success",
    "Description": "Whether the operation succeeded",
    "Type": 0
  }
]
```

### 2. UpdateCustomAPI

Updates mutable fields on an existing Custom API. Immutable fields (uniquename, bindingtype, isfunction, etc.) cannot be changed after creation.

```powershell
powershell -ExecutionPolicy Bypass -File "claude-code/skills/aidevme-dataverse-customapi/scripts/Invoke-DataverseCustomAPIOperation.ps1" `
    -Operation UpdateCustomAPI `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -APIUniqueName "hso_ActionName" `
    -APIDisplayName "New Display Name" `
    -APIDescription "Updated description" `
    -PluginTypeName "NewNamespace.Plugins.NewPluginClass" `
    -SolutionName "YourSolutionName"
```

**Updatable Fields:**

| Field | Description |
|-------|-------------|
| APIDisplayName | Display name |
| APIDescription | Description |
| IsPrivate | Show/hide in Power Automate |
| PluginTypeName | Re-link to a different plugin type |

### 3. QueryCustomAPI

Query a Custom API with expanded request parameters, response properties, and plugin type.

```powershell
powershell -ExecutionPolicy Bypass -File "claude-code/skills/aidevme-dataverse-customapi/scripts/Invoke-DataverseCustomAPIOperation.ps1" `
    -Operation QueryCustomAPI `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -APIUniqueName "hso_ActionName"
```

**Output includes:**
- Custom API metadata (uniquename, binding type, isfunction, etc.)
- Linked plugin type (typename, assembly, version)
- All request parameters (name, type, optional/required)
- All response properties (name, type)

### 4. QueryPluginType

Find a plugin type by class name. Use this to verify the plugin assembly is deployed.

```powershell
powershell -ExecutionPolicy Bypass -File "claude-code/skills/aidevme-dataverse-customapi/scripts/Invoke-DataverseCustomAPIOperation.ps1" `
    -Operation QueryPluginType `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -PluginTypeName "HSO.Plugins.SubmitForApprovalPlugin"
```

Searches by exact `typename` first, then falls back to `contains(name, ...)`.

### 5. DeleteCustomAPI

Deletes a Custom API and all its request parameters and response properties (cascading delete).

```powershell
powershell -ExecutionPolicy Bypass -File "claude-code/skills/aidevme-dataverse-customapi/scripts/Invoke-DataverseCustomAPIOperation.ps1" `
    -Operation DeleteCustomAPI `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -APIUniqueName "hso_ActionName"
```

### 6. AddRequestParameter

Add a request parameter to an existing Custom API.

```powershell
powershell -ExecutionPolicy Bypass -File "claude-code/skills/aidevme-dataverse-customapi/scripts/Invoke-DataverseCustomAPIOperation.ps1" `
    -Operation AddRequestParameter `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -APIUniqueName "hso_ActionName" `
    -ParamUniqueName "NewParam" `
    -ParamDisplayName "New Parameter" `
    -ParamDescription "Description of new parameter" `
    -ParamType 10 `
    -ParamIsOptional $true `
    -SolutionName "YourSolutionName"
```

### 7. AddResponseProperty

Add a response property to an existing Custom API.

```powershell
powershell -ExecutionPolicy Bypass -File "claude-code/skills/aidevme-dataverse-customapi/scripts/Invoke-DataverseCustomAPIOperation.ps1" `
    -Operation AddResponseProperty `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -APIUniqueName "hso_ActionName" `
    -ParamUniqueName "NewProperty" `
    -ParamDisplayName "New Property" `
    -ParamDescription "Description of new property" `
    -ParamType 7 `
    -SolutionName "YourSolutionName"
```

### 8. DeleteRequestParameter / DeleteResponseProperty

Remove a parameter or property by name:

```powershell
# Delete by API name + parameter name
powershell -ExecutionPolicy Bypass -File "claude-code/skills/aidevme-dataverse-customapi/scripts/Invoke-DataverseCustomAPIOperation.ps1" `
    -Operation DeleteRequestParameter `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -APIUniqueName "hso_ActionName" `
    -ParamUniqueName "ObsoleteParam" `

# Delete by GUID
powershell -ExecutionPolicy Bypass -File "claude-code/skills/aidevme-dataverse-customapi/scripts/Invoke-DataverseCustomAPIOperation.ps1" `
    -Operation DeleteResponseProperty `
    -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -PropertyId "a1b2c3d4-5678-90ab-cdef-1234567890ab"
```

---

## Type Codes

| Type | Code | C# Type |
|------|------|---------|
| Boolean | 0 | `bool` |
| DateTime | 1 | `DateTime` |
| Decimal | 2 | `decimal` |
| Entity | 3 | `Entity` |
| EntityCollection | 4 | `EntityCollection` |
| EntityReference | 5 | `EntityReference` |
| Float | 6 | `double` |
| Integer | 7 | `int` |
| Money | 8 | `Money` |
| Picklist | 9 | `OptionSetValue` |
| String | 10 | `string` |
| StringArray | 11 | `string[]` |
| Guid | 12 | `Guid` |

See [references/type-codes.md](references/type-codes.md) for complete reference including binding types and field specifications.

---

## Binding Types

| Type | Code | Use Case |
|------|------|----------|
| Global | 0 | Not bound to entity (most common) |
| Entity | 1 | Bound to single entity record |
| EntityCollection | 2 | Bound to entity collection |

**Note:** Entity/EntityCollection binding requires `BoundEntityLogicalName`.

---

## Immutable vs Mutable Fields (digest)

Digest only — Section 3 of the [Custom API Best Practices SOP](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md#3-the-custom-api-metadata-model) is authoritative; read it before designing, and note it also covers `workflowsdkstepenabled` (immutable) and the immutability of request-parameter/response-property fields (`uniquename`, `type`, `isoptional`, `logicalentityname`).

After creation, these customapi fields **cannot be changed**: uniquename, bindingtype, boundentitylogicalname, isfunction, allowedcustomprocessingsteptype, workflowsdkstepenabled. Mutable: displayname, description, isprivate, plugintypeid, executeprivilegename. To change any immutable field after a managed import, ship a v2 (new uniquename) and deprecate v1 — see [SOP Section 21](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md#21-versioning-deprecation-and-immutability).

---

## Quick Example

Custom API `hso_SubmitForApproval` with:
- Input: `Target` (EntityReference, required)
- Outputs: `Success` (Boolean), `Message` (String)

```powershell
# 1. Deploy plugin first (use deploy-plugin skill)

# 2. Verify plugin type exists
powershell -ExecutionPolicy Bypass -File "claude-code/skills/aidevme-dataverse-customapi/scripts/Invoke-DataverseCustomAPIOperation.ps1" -Operation QueryPluginType -EnvironmentUrl "https://hsousconfigdemo.crm.dynamics.com" -PluginTypeName "HSO.Plugins.SubmitForApprovalPlugin"

# 3. Create Custom API with parameters and properties in one call (single line)
powershell -ExecutionPolicy Bypass -File "claude-code/skills/aidevme-dataverse-customapi/scripts/Invoke-DataverseCustomAPIOperation.ps1" -Operation CreateCustomAPI -EnvironmentUrl "https://hsousconfigdemo.crm.dynamics.com" -APIUniqueName "hso_SubmitForApproval" -APIDisplayName "Submit For Approval" -APIDescription "Submits a record for approval processing" -PluginTypeName "HSO.Plugins.SubmitForApprovalPlugin" -RequestParametersJson '[{"UniqueName":"Target","DisplayName":"Target","Description":"Record to submit","Type":5,"IsOptional":false}]' -ResponsePropertiesJson '[{"UniqueName":"Success","DisplayName":"Success","Description":"Whether the operation succeeded","Type":0},{"UniqueName":"Message","DisplayName":"Message","Description":"Result message","Type":10}]' -SolutionName "EstimationSolution"

# 4. Verify
powershell -ExecutionPolicy Bypass -File "claude-code/skills/aidevme-dataverse-customapi/scripts/Invoke-DataverseCustomAPIOperation.ps1" -Operation QueryCustomAPI -EnvironmentUrl "https://hsousconfigdemo.crm.dynamics.com" -APIUniqueName "hso_SubmitForApproval"
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Authentication not resolved | Verify the environment settings and rerun; auth is resolved automatically |
| Duplicate key error | Custom API already exists - use QueryCustomAPI to verify, then update or delete |
| Custom API doesn't execute | Check `plugintypeid` is linked (not `(none)` in QueryCustomAPI output) |
| Plugin type not found | Deploy plugin assembly first with `deploy-plugin` skill |
| "Authentication failed" | Check your Office 365 credentials |
| "MSAL.PS module not found" | Module is auto-installed on first use |
| Cannot update uniquename | Immutable field - delete and recreate the Custom API |
| JSON parse error | Use `-File` invocation (not `-Command`). JSON passes through cleanly with `-File`. |

---

## Migration from MCP Server

This skill was migrated from using the Dataverse MCP Server to direct Web API calls. Benefits:
- **No MCP dependency** - Works without the Dataverse MCP Server being configured
- **Single deep insert** - Creates API + all parameters + all properties in one call
- **Consistent pattern** - Uses the same PowerShell/Web API pattern as `hso-dataverse-data-modeling` and `hso-dataverse-ui-config` skills
- **Token caching** - Shared auth cache with other Dataverse skills

---

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
