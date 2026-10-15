---
name: hso-powerautomate-writer
layer: atomic
scope: core
description: |
  Author Power Automate cloud flow JSON definitions using the Microsoft Dataverse connector
  and deploy them to a Dataverse environment via the Web API. Use when:
  (1) User asks to "create a flow", "build a Power Automate flow", or "author a cloud flow"
  (2) User asks to "deploy a flow" or "upload a flow to Dataverse"
  (3) User asks to "add actions to a flow" or "modify an existing flow definition"
  (4) User provides a flow specification or requirement that involves Dataverse triggers/actions
  (5) User asks to validate a flow JSON definition
  This skill focuses on the Microsoft Dataverse connector (shared_commondataserviceforapps).
  Does NOT cover non-Dataverse connectors (SharePoint, Outlook, Teams, etc.) in this version.
  Does NOT generate flow documentation — use hso-dataverse-flow-docs for that.
---

# Power Automate Flow Writer

Author Power Automate cloud flow JSON definitions using the Microsoft Dataverse connector and deploy them to Dataverse environments.

## Slice Consumption Contract (executor side of the architect→builder pipeline)

**Authority:** [`slice-consumption-contract-best-practices.md`](../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md) — read before building any slice inside the pipeline. That SOP is the **canonical, executor-side contract** for [ADR 0018](../../../agent/wiki/decisions/0018-agentic-delivery-architect-builder-pipeline.md)'s architect→builder pipeline (the five rules, single-writer, reviewable-unit, anti-mis-attribution). The summary here is a labeled pointer, not a substitute.

When the architect routes a slice to this skill you are handed **the spec + its `spec.json` sidecar + a target slice `id`**. Build **exactly that slice's `touches`** and nothing more; trust and verify — don't rebuild — your `blocked_by` slices; honor every recorded design decision (trigger, actions, the premium-connector / licence call the spec made); **read back against the slice's `acceptance`, not against an SOP rule the spec never invoked**; and end at the **reviewable unit** (never auto-merge).

**Logic-bearing slice.** A cloud flow carries logic, so its reviewable unit is the **unmanaged solution holding the flow + its connection references** (the `solution` named in `spec.json`), and the read-back is the **flow definition** — confirm the flow *does what the slice specified* (trigger, actions, expressions all match the acceptance), not merely that *a* flow exists. A premium-connector or licence implication the spec named is the **architect's** decision; honor it, don't second-guess it.

| When a slice's `touches` include… | What this skill owns | Read-back against `acceptance` |
|---|---|---|
| a **cloud flow** (logic-bearing) | the flow definition (trigger + actions + expressions) + its connection references, in the unmanaged solution | the **flow definition** asserted against the slice's `acceptance` (trigger/actions/expressions match what the slice specified) |

> All executor skills share the **same** [Slice Consumption Contract](../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md); flow **documentation** is [`hso-dataverse-flow-docs`](../hso-dataverse-flow-docs/SKILL.md), not part of the build slice.

## Prerequisites

- Dataverse environment URL configured in `CLAUDE.md`
- Default solution name configured in `CLAUDE.md`
- MSAL.PS module installed (for deployment operations)
- Connection reference logical name for the Dataverse connector in the target solution

## Configuration

Read from `CLAUDE.md`: **Environment URL** · **Default Solution** · **Publisher Prefix**
Read from `CLAUDE.local.md`: **Author Name**

## CRITICAL: Best Practices References

This skill defers to several authoritative SOPs. Each line below states what the
doc governs and that it is read-before-doing. Read the primary authority for your
task **before** designing, naming, deploying, or integrating a flow.

- **Authority for flow design & performance (triggers, error handling, anti-patterns) — read before designing any flow:** [`shared/dv/agent/wiki/sop/power-automate/power-automate-cloud-flow-best-practices.md`](../../../shared/dv/agent/wiki/sop/power-automate/power-automate-cloud-flow-best-practices.md)
- **Authority for ALM, deployment, ownership & monitoring — read before deploying or solution-packaging a flow:** [`shared/dv/agent/wiki/sop/power-automate/power-automate-alm-and-governance.md`](../../../shared/dv/agent/wiki/sop/power-automate/power-automate-alm-and-governance.md)
- **Authority for flow & action naming — read before naming the flow:** [`shared/dv/agent/wiki/sop/dataverse-naming-conventions.md`](../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md) (Power Automate Flow Naming section)
- **Authority for Custom API call/subscribe rules — read before authoring a flow that calls or subscribes to a Custom API:** [`shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md`](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md) (§13 call / §6 subscribe)
- **Authority for Azure integration surfaces — read before authoring a system-to-system integration flow:** [`shared/dv/agent/wiki/sop/azure-integration/azure-integration-best-practices.md`](../../../shared/dv/agent/wiki/sop/azure-integration/azure-integration-best-practices.md)
- **Spec reference (what a spec must capture — not a governing authority for authoring):** [`shared/dv/agent/wiki/references/powerautomate-flow-spec-template.md`](../../../shared/dv/agent/wiki/references/powerautomate-flow-spec-template.md)

### Task → primary authority

| Task | Primary authority |
|------|-------------------|
| Design/author any flow (triggers, actions, error handling, perf) | `power-automate-cloud-flow-best-practices.md` |
| Build flow JSON (trigger/action/control-flow shape) | `references/dataverse-connector-reference.md` + `control-flow-reference.md` + `expression-functions-reference.md` |
| Deploy / solution-package / set ownership | `power-automate-alm-and-governance.md` |
| Name the flow / actions | `dataverse-naming-conventions.md` (Power Automate Flow Naming) |
| Flow calls or subscribes to a Custom API | `custom-api-best-practices.md` (§13 call / §6 subscribe) |
| Flow is a system-to-system Azure integration surface | `azure-integration-best-practices.md` |

**Supporting detail for the conditional authorities:**

- **Custom API** — When the flow **calls** a Custom API (Perform an unbound action / Perform a bound action), read §13 [Calling from Power Automate](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md#13-calling-from-power-automate): connector picker visibility rules (`IsPrivate=false`, `IsFunction=false`, `WorkflowSdkStepEnabled=true`), the type restrictions enforced by `WorkflowSdkStepEnabled` (no `Entity` / `EntityCollection` / `StringArray`), and the HTTP-with-Entra-ID escape hatch. When the flow uses the **"When an action is performed" trigger** to subscribe to a Custom API, also read §6 [AllowedCustomProcessingStepType](../../../shared/dv/agent/wiki/sop/custom-api/custom-api-best-practices.md#6-allowedcustomprocessingsteptype): the trigger silently never fires unless the API is configured `AllowedCustomProcessingStepType=2 (SyncAndAsync)`.
- **Azure integration** — When the flow is an integration surface to Azure (Service Bus / Function / Logic App / Custom Connector / external API), read particularly: §1 (decision matrix — is Power Automate the right surface for this work, vs Service Bus → Function or Logic App?), §7.1 (use **Filter Expression** server-side OData on the Dataverse trigger, not Trigger Conditions client-side), §7.2 (**HSO Override: never enable apply-to-each concurrency on Dataverse-writing flows** — 4 engagements of 429 cascade evidence), §7.3 (SPN-owned flows in production), §7.4 (Connection References as the ALM linchpin; deployment-settings-JSON pattern), §8.4 (**HSO Override: never grant System Administrator to the flow's application user**), §9 (service-protection limits — Polly retry pattern, multi-app-user pool), §13 (naming, Environment Variables, Key Vault references for ALL secrets).

## Workflow

### 1. Gather Requirements

Before building any flow, collect:

1. **Flow name** — descriptive name following pattern: `Entity | On Event | Action Description`
2. **Trigger type** — which event starts the flow (see Trigger Reference below)
3. **Trigger configuration** — table name, change type, scope, filters
4. **Actions** — ordered list of what the flow does (CRUD operations, conditions, loops)
5. **Connection reference** — the logical name of the Dataverse connection reference in the solution

**MANDATORY**: Use `hso-dataverse-data-modeling` skill to query table/column metadata before referencing any entity or attribute names in the flow definition.

If any requirement is ambiguous, use `AskUserQuestion` to clarify before proceeding.

### 2. Build the Flow JSON

Construct the flow definition following the Workflow Definition Language schema. The flow JSON has this top-level structure:

```json
{
  "properties": {
    "connectionReferences": {
      "shared_commondataserviceforapps": {
        "runtimeSource": "embedded",
        "connection": {
          "connectionReferenceLogicalName": "<from-solution>"
        },
        "api": { "name": "shared_commondataserviceforapps" }
      }
    },
    "definition": {
      "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {
        "$connections": { "defaultValue": {}, "type": "Object" },
        "$authentication": { "defaultValue": {}, "type": "SecureObject" }
      },
      "triggers": { },
      "actions": { }
    },
    "templateName": ""
  },
  "schemaVersion": "1.0.0.0"
}
```

**Authority for flow JSON shape (triggers/actions/control-flow/expressions) — read before constructing the definition:**
- [references/dataverse-connector-reference.md](references/dataverse-connector-reference.md) — All trigger and action JSON patterns
- [references/control-flow-reference.md](references/control-flow-reference.md) — Conditions, loops, scopes, variables, and expressions
- [references/expression-functions-reference.md](references/expression-functions-reference.md) — Complete expression function catalog

#### Key Construction Rules

1. **Action names** use underscores for spaces: `Get_a_row_by_ID`, `List_rows`
2. **Generate new GUIDs** for every `operationMetadataId` — never reuse from templates
3. **runAfter** controls execution order — the first action after the trigger has `"runAfter": {}`
4. **Every Dataverse action** must include `"authentication": "@parameters('$authentication')"`
5. **Lookup bindings** use the entity set name (plural): `"item/field@odata.bind": "accounts(<guid>)"`
6. **Trigger field references**: `@triggerOutputs()?['body/<fieldname>']`
7. **Trigger lookup references**: `@triggerOutputs()?['body/_<fieldname>_value']`
8. **Environment variables**: consume via `@parameters('Display Name (prefix_schemaname)')` declared in the flow's `parameters` block — never query `environmentvariablevalue`
9. **Required fields on create**: every business-required column must be present as an `item/<field>` key; if intentionally blank, set it to `"@{null}"` rather than omitting it
10. **Power Pages response outputs**: use the same lowercase name for each schema property key, its `title`, and the corresponding body key. See [Power Pages response outputs](references/control-flow-reference.md#power-pages-response-outputs).

### 3. Generate Companion XML

Every flow needs a companion `.json.data.xml` file for solution compatibility:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Workflow WorkflowId="{<new-guid>}" Name="<Flow Display Name>"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <JsonFileName>/Workflows/<FileName>-<GUID>.json</JsonFileName>
  <Type>1</Type>
  <Subprocess>0</Subprocess>
  <Category>5</Category>
  <Mode>0</Mode>
  <Scope>4</Scope>
  <OnDemand>0</OnDemand>
  <TriggerOnCreate>0</TriggerOnCreate>
  <TriggerOnDelete>0</TriggerOnDelete>
  <AsyncAutodelete>0</AsyncAutodelete>
  <SyncWorkflowLogOnFailure>0</SyncWorkflowLogOnFailure>
  <StateCode>1</StateCode>
  <StatusCode>2</StatusCode>
  <RunAs>1</RunAs>
  <IsTransacted>1</IsTransacted>
  <IntroducedVersion>1.0.0.0</IntroducedVersion>
  <IsCustomizable>1</IsCustomizable>
  <BusinessProcessType>0</BusinessProcessType>
  <IsCustomProcessingStepAllowedForOtherPublishers>1</IsCustomProcessingStepAllowedForOtherPublishers>
  <ModernFlowType>0</ModernFlowType>
  <PrimaryEntity>none</PrimaryEntity>
  <LocalizedNames>
    <LocalizedName languagecode="1033" description="<Flow Display Name>" />
  </LocalizedNames>
</Workflow>
```

### 4. Save Output Files

Save generated files to `agent/work/build/flows/` (create the folder if the repo doesn't have it yet):

```
agent/work/build/flows/
  <FlowName>-<GUID>.json
  <FlowName>-<GUID>.json.data.xml
```

The filename format mirrors Dataverse solution export conventions: PascalCase flow name (spaces removed) followed by the workflow GUID.

> **Legacy layout.** If the repo still uses the pre-hybrid numbered folders (`agent/06_build/`), write there instead and tell the user the repo predates the hybrid `agent/work/` layout — see [`hso-wiki-scaffold-project`](../hso-wiki-scaffold-project/SKILL.md) for the migration. Never create `agent/06_build/` in a repo that already has `agent/work/`.

### 5. Deploy Flow (Optional)

When the user asks to deploy the flow, run the deployment script:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-powerautomate-writer/scripts/Invoke-FlowDeployment.ps1" `
  -Operation DeployFlow `
  -FlowJsonPath "agent/work/build/flows/<FlowName>-<GUID>.json" `
  -FlowName "<Flow Display Name>" `
  -SolutionUniqueName "<solution-name>" `
  -EnvironmentUrl "<environment-url>"
```

**Operations:**

| Operation | Description |
|-----------|-------------|
| `DeployFlow` | Create workflow record, add to solution, optionally activate |
| `UpdateFlow` | Update an existing flow's definition (clientdata) by workflow ID |
| `GetFlow` | Read a workflow record's state, parsed clientdata, and connection refs (by `-WorkflowId` or `-FlowName`); optionally writes clientdata to disk via `-OutputPath` |
| `ActivateFlow` | Activate an existing flow by workflow ID |
| `DeactivateFlow` | Deactivate a flow by workflow ID |
| `GetConnectionReference` | Query connection reference logical names from a solution |
| `CreateConnectionReference` | Create a new Dataverse connection reference in a solution |

**UpdateFlow example:**

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-powerautomate-writer/scripts/Invoke-FlowDeployment.ps1" `
  -Operation UpdateFlow `
  -WorkflowId "<existing-workflow-guid>" `
  -FlowJsonPath "agent/work/build/flows/<FlowName>-<GUID>.json" `
  -EnvironmentUrl "<environment-url>"
```

> **Note:** UpdateFlow patches the `clientdata` field on the existing workflow record. The flow may need to be deactivated and reactivated for changes to take effect. Connection references are preserved — the flow keeps its existing connections.

**GetFlow example:**

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-powerautomate-writer/scripts/Invoke-FlowDeployment.ps1" `
  -Operation GetFlow `
  -WorkflowId "<existing-workflow-guid>" `
  -OutputPath "agent/work/build/flows/<FlowName>-deployed.json" `
  -EnvironmentUrl "<environment-url>"
```

> **Note:** Use `GetFlow` to diagnose drift between source-of-truth flow JSON on disk and what's actually deployed in Dataverse. Returns `statecode`/`statuscode`, the parsed `clientdata` (triggers, actions, connection references), and — with `-OutputPath` — pretty-prints the deployed clientdata to a file for diff against the source. Look up by `-WorkflowId` (preferred, immutable) or by `-FlowName` (filtered to category=5 / Modern Flow). Useful when 502s, missing run records, or activation failures suggest the deployed definition diverged from the file you patched.

> **502 NoResponse troubleshooting**: when an HTTP-trigger flow returns `HTTP 502 / x-ms-failure-cause: Trigger / code: NoResponse` to the caller, the cause is usually that the flow **did** execute a run (visible in the maker UI run history), but a downstream action with `runAfter: Succeeded` failed, leaving the `Response` action orphaned. The gateway then times out and returns 502. **Always check Run history first** — the actual error is there, not in the gateway response. Toggling "Who can trigger" or deactivate/reactivate cycles are red herrings.

**CreateConnectionReference example:**

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-powerautomate-writer/scripts/Invoke-FlowDeployment.ps1" `
  -Operation CreateConnectionReference `
  -ConnectionReferenceLogicalName "hso_sharedcommondataserviceforapps_<suffix>" `
  -ConnectionReferenceDisplayName "Dataverse (<SolutionDisplayName>)" `
  -ConnectorId "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps" `
  -SolutionUniqueName "<solution-name>" `
  -EnvironmentUrl "<environment-url>"
```

### 6. Validate Flow (Optional)

Before deployment, validate the flow JSON:

- All action names are unique within their scope
- All `runAfter` references point to existing actions in the same scope
- All `operationMetadataId` values are valid GUIDs
- All `entityName` parameters reference valid Dataverse tables
- All expressions use valid function names
- Connection references are consistent throughout
- No circular `runAfter` dependencies

## Trigger Quick Reference

| Trigger | Type | OperationId | Key Parameters |
|---------|------|-------------|----------------|
| Row added/modified/deleted | `OpenApiConnectionWebhook` | `SubscribeWebhookTrigger` | message (1=Create,2=Delete,3=Update,4=CreateOrUpdate), entityname, scope (1-4), filteringattributes, filterexpression |
| Row selected (command bar) | `OpenApiConnectionWebhook` | `OnRecordSelected` | entityname, schema |
| Action performed | `OpenApiConnectionWebhook` | `BusinessEventsTrigger` | catalog, category, entityname, sdkmessagename |
| Manual/Button | `Request` (kind: `Button`) | n/a | schema (input parameters) |
| Scheduled | `Recurrence` | n/a | frequency, interval, startTime, timeZone, schedule |

## Action Quick Reference

| Action | OperationId | Key Parameters |
|--------|-------------|----------------|
| Add a new row | `CreateRecord` | entityName, item/* |
| Update a row | `UpdateOnlyRecord` | entityName, recordId, item/* |
| Delete a row | `DeleteRecord` | entityName, recordId |
| Get a row by ID | `GetItem` | entityName, recordId, $select, $expand |
| List rows | `ListRecords` | entityName, $select, $filter, $orderby, $top, fetchXml |
| Upsert a row | `UpdateRecord` | entityName, recordId, item/* |
| Relate rows | `AssociateEntities` | entityName, recordId, associationEntityRelationship, `item/@odata.id` (full URL) |
| Unrelate rows | `DisassociateEntities` | entityName, recordId, associationEntityRelationship, `$id` (full URL) |
| Bound action | `PerformBoundAction` | entityName, actionName, recordId |
| Unbound action | `PerformUnboundAction` | actionName |
| Changeset | `ExecuteChangeset` | (wraps multiple actions in transaction) |

> **Bound vs unbound is not a style choice** — a message that exists only unbound in the Web API
> (e.g. `CalculateRollupField`) authored as a `PerformBoundAction` step deploys but can **never
> activate** (`InvalidOpenApiFlow`; Bug #298). `Invoke-FlowDeployment.ps1` rejects known
> unbound-only messages at deploy time; see *Unbound-only messages* in
> [dataverse-connector-reference.md](references/dataverse-connector-reference.md) for the failure
> signature and the alternatives (drop the step when a rollup-refresh plugin covers it / platform
> periodic recalc / HTTP-request pattern).

## Connector Parameter-Shape Gotchas

Power Automate connector parameter names are not always discoverable from the action UI alone. When stuck on a `WorkflowOperationParametersExtraParameter` error (or 502 with bad payload), use the **throwaway-flow technique**: have the user create a one-action flow in maker UI, save it, then `Operation GetFlow -FlowName "<test name>"` to read the exact JSON shape the maker produced. Apply that pattern to your authored flow.

### Dataverse M:N association (Associate / Disassociate)

| Operation | OperationId | Required parameters |
|-----------|-------------|---------------------|
| Associate | `AssociateEntities` | `entityName` (source table), `recordId` (source record GUID), `associationEntityRelationship` (NOT `associationName` or `relationship`), `item/@odata.id` (**full absolute URL** to related record) |
| Disassociate | `DisassociateEntities` | Same first three + `$id` (NOT `relatedRecordId`; **full absolute URL** to related record) |

**URL format**: `https://<org>.crm.dynamics.com/api/data/v9.1/<collection>(<id>)`. The connector requires **API version 9.1** specifically — `v9.0` returns `URI ... is not based on '<orgUrl>/api/data/v9.1/'`. Relative URIs (`/queues(<id>)` or `queues(<id>)`) are rejected: `relative URI value was specified in the payload, but the odata.context annotation is missing`.

### HTTP with Microsoft Entra ID (v2)

| Connector ID | Operation | Parameter shape |
|--------------|-----------|-----------------|
| `shared_webcontentsv2` | `InvokeHttp` | `request/method` (lowercase, slash-nested), `request/url`, optional `request/body`, `request/headers/<name>` |

**Note**: this is the v2 connector. The earlier `shared_webcontents` (v1) used different parameter names and is being phased out. When creating connection references for Graph or Entra-protected APIs, use `shared_webcontentsv2` as the connector id. Base Resource URL = Microsoft Entra ID Resource URI = `https://graph.microsoft.com` for Graph.

### Bookable Resource and related entities

| Entity | Lookup nav prop convention | Notes |
|--------|---------------------------|-------|
| `bookableresource.userid` | `UserId` (PascalCase) | Lookup attribute is `userid` (lowercase) but the navigation property name on the entity is **PascalCase**. Bind via `item/UserId@odata.bind` (NOT `item/userid@odata.bind`). |
| `bookableresource` create required fields | `name`, `resourcetype` (3=User), `msdyn_displayonscheduleboard` (Field Service field — set `false` for non-FS Customer Service agents), `UserId@odata.bind` | |
| `msdyn_bookableresourcecapacityprofile` | 1:N intersect entity (NOT M:N) | Required fields on create: `msdyn_name` (string), `item/msdyn_bookableresourceid@odata.bind`, `item/msdyn_capacityprofileid@odata.bind` (both nav props lowercase). Delete by intersect record ID. Plural collection: `msdyn_bookableresourcecapacityprofiles`. |

## Known Issues

### `UpdateFlow` wipes the trigger access mode

`UpdateFlow` PATCHes the workflow's `clientdata` field, but the trigger access mode setting ("Who can trigger this flow" — Anyone / Any user in my tenant / Specific users) lives **outside** `clientdata` (likely on a separate workflow property or related entity). Every `UpdateFlow` resets this field, requiring a manual save in the maker UI to re-set the desired access mode.

`Activate/DeactivateFlow` cycles also reset it.

**Workaround**: avoid deactivate/reactivate when possible — use `UpdateFlow` directly on an active flow, then have the user click Save in the maker UI to re-apply the trigger access mode.

**Eventual fix**: skill should either preserve this on `UpdateFlow` or expose an `-AccessMode` parameter that re-applies the setting after the PATCH.

### `filter()` is not a Power Automate WDL function

When filtering arrays in flow expressions, `filter(array, predicate)` does NOT exist as a template function (unlike `length`, `first`, `concat`, etc.). Use the **`Filter array` action** instead (action `type: Query`, with `from`/`where` inputs). Same applies to `select()` → use `Select` action.

## Critical Rules

### DO — Construction
- Query Dataverse metadata FIRST via `hso-dataverse-data-modeling` before referencing any table or column
- Generate fresh GUIDs for every `operationMetadataId` and workflow ID
- Use connection reference logical names from the target solution
- Include `"authentication": "@parameters('$authentication')"` on every Dataverse action
- Use the `?` (null-safe) operator when accessing output properties: `?['body/field']`
- Follow the naming conventions in [`shared/dv/agent/wiki/sop/dataverse-naming-conventions.md`](../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md) (Power Automate Flow Naming section)
- Save both `.json` and `.json.data.xml` files
- Validate OData filter expressions for correct syntax

### DO — Best Practices (digest only — the Power Automate Cloud Flow Best Practices SOP is authoritative; read it before designing)

The bullets below are a quick-reference subset; the SOP carries the full ruleset (trigger conditions vs filter expressions, retry policies, CreateMultiple/UpdateMultiple bulk operations, secure inputs/outputs, the irreversible-concurrency warning).

- **Always set `filteringattributes`** on Update triggers — without them the flow fires on every field change (including system fields like `modifiedon`)
- **Always set `filterexpression`** when the flow should only process a subset of records (e.g., `statecode eq 0`)
- **Use descriptive action names** that explain what the action does, not the default action type name (e.g., `Get_Parent_Account` not `Get_a_row_by_ID`)
- **Use Scopes for try-catch error handling** — wrap business logic in a Try scope, add a Catch scope with `runAfter: Failed/TimedOut`, and a Finally scope for cleanup
- **Use `$select` on every Get/List action** — never retrieve all columns
- **Use `$filter` server-side** instead of filtering in conditions or loops
- **Prefer data operations over loops** — use Filter Array, Select, and Compose instead of Apply to Each when possible
- **Use environment variables** for any value that differs between environments (GUIDs, URLs, email addresses, thresholds)
- **Single responsibility** — each flow should do one thing well; split mega-flows into separate flows or use child flows

### DO NOT
- Hardcode environment URLs — always read from `CLAUDE.md`
- Reuse `operationMetadataId` GUIDs from other flows or templates
- Reference table or column names without first querying metadata
- Forget the `runAfter` property on actions (even if empty `{}` for the first action)
- Use the old `shared_commondataservice` connector — always use `shared_commondataserviceforapps`
- Create flows with non-Dataverse connectors (out of scope for this version)
- Deploy without asking the user for confirmation first
- **Hardcode GUIDs, email addresses, or URLs** in expressions — use environment variables
- **Query the `environmentvariablevalue` / `environmentvariabledefinition` tables** to read a config value — bind the environment variable as a flow parameter and reference it with `@parameters('Display Name (prefix_schemaname)')` instead
- **Leave a business-required column off a create** — every required (`ApplicationRequired` / `SystemRequired`) column must be present as an `item/<field>` key; if it is meant to be blank, set it explicitly to `"@{null}"` rather than omitting it (an omitted required field leaves the record incomplete for the human editor)
- **Use mixed-case Power Pages response output names or let the schema property key and `title` differ**
- **Omit filtering attributes on Update triggers** — this is the #1 performance anti-pattern
- **Create flows that update fields they trigger on** — this causes infinite loops (use filtering attributes to exclude fields the flow updates)
- **Nest Apply to Each loops** without justification — quadratic complexity; flatten with Select/Filter or use FetchXML joins
- **Use Power Automate for synchronous validation** — flows run async after commit; use plugins for pre-save validation

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
