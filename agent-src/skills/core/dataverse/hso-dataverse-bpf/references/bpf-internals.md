# BPF Internals & Gotchas

Hard-won reference for working with Dataverse Business Process Flows (BPFs) via the Web API.
Grounded in Microsoft Learn ([Work with BPFs using code](https://learn.microsoft.com/power-automate/developer/business-process-flows-code),
[Best practices for BPF table columns](https://learn.microsoft.com/power-automate/best-practices-entity-attributes))
plus field debugging. Example values use a fictitious **Contoso** "Quote Process" BPF.

---

## The data model

A modern (entity-bound) BPF has **three** moving parts:

| Part | Entity | What it is |
|---|---|---|
| **Definition** | `workflow` (category = 4) | The BPF design. Holds `clientdata` (the stage graph), `uniquename`, `primaryentity`, state. |
| **Stages** | `processstage` | One row per stage. `stagename`, `processstageid`, `stagecategory`, `_processid_value`. **Unordered when queried.** |
| **Instance** | `<workflow.uniquename>` | One row per record that the BPF is running on. This is the **source of truth** for the active stage. |

The instance entity logical name **equals the workflow's `uniquename`**. Example: `uniquename =
contoso_quoteprocess`, so the instance entity is `contoso_quoteprocess` (entity set
`contoso_quoteprocesses`).

### Instance entity columns

| Column | Type | Points to |
|---|---|---|
| `<primaryid>` e.g. `businessprocessflowinstanceid` | uniqueidentifier | the instance row |
| `processid` | lookup | the `workflow` (BPF) |
| `activestageid` | lookup | the current `processstage` |
| `bpf_<primaryentity>id` e.g. `bpf_incidentid` | lookup | the primary record |
| `traversedpath` | string | comma-separated stage GUIDs visited, in order |
| `statecode` / `statuscode` | state | see state codes below |

### State codes (instance vs definition are OPPOSITE — classic confusion)

| Entity | Active/usable value | Notes |
|---|---|---|
| **Instance** (`contoso_quoteprocess`) | `statecode = 0` (Active) | `statuscode`: 1 = Active, 2 = Finished, 3 = Aborted |
| **Definition** (`workflow`) | `statecode = 1`, `statuscode = 2` (Activated) | must be Activated before instances can be created |

---

## Gotcha 1 — Don't drive BPF state by writing the primary record's process columns

The primary record (e.g. `incident`) has its own `processid`, `stageid`, and `traversedpath`
columns. Microsoft documents them as **legacy and deprecated**: *"Manipulating these legacy process
related columns for target table rows does not guarantee consistency of the business process flow
state, and is not a supported scenario."* In practice a direct `PATCH` of them returns HTTP success
and **persists nothing**. The **instance entity record is the real source of truth**.

**The one supported exception (per Microsoft):** you *may* set `ProcessId` on the primary record
**at create time** to override which BPF auto-applies — set it to a specific BPF, or to
`Guid.Empty` to skip applying any BPF to the new record. That is the *only* sanctioned write to
these columns, and only on create.

## Gotcha 2 — A blank process bar has several causes; check them in order

A valid, active instance is **not** sufficient for the bar to render. Community + docs converge on
these causes, roughly in order of frequency:

1. **Security roles.** The BPF instance table defaults to **System Administrator / System Customizer
   only**. For any other role the bar silently disappears even when access to the *primary* table is
   fine. Enable roles on the BPF (designer -> *Edit security roles*).
2. **BPF not added to the app.** BPFs are model-driven app components; a newly-created BPF is in no
   app. Add it (`AddToApp`), publish, reload.
3. **Sync / cache.** Re-publish; reload the form fresh.

Diagnostic: append **`&monitor=true`** to the record URL (or *Monitor* from the app's command bar)
to launch the **BPF Monitor**, which reports why a flow isn't rendering. `QueryAppInclusion` and a
role check narrow it from the data side. Note: "add to app fixes it" is a *likely* fix, not a
certainty — confirm with the Monitor rather than assuming.

## Gotcha 3 — Stage ORDER lives in clientdata, not processstage (and only for LINEAR flows)

`GET processstages?$filter=_processid_value eq <bpf>` returns stages in **arbitrary order**. The
left-to-right order is encoded in `workflow.clientdata` as a **nextStageId chain** (each `StageStep`
has `stageId` + `nextStageId`; head = the stage no other stage points to; tail = `nextStageId:null`).
This skill walks that chain.

**Limitation:** this assumes a **single linear path**. **Branched BPFs** (conditional stages) have
multiple paths and the linear walk will mis-order or break. `clientdata` is also an **undocumented,
read-only** blob — a Microsoft format change can break the parser silently. For branched flows, or
for a supported contract, use the **`RetrieveActivePath`** and **`RetrieveProcessInstances`**
messages instead ([docs](https://learn.microsoft.com/power-automate/developer/business-process-flows-code#use-retrieveprocessinstances-and-retrieveactivepath-messages)).
`RetrieveProcessInstances` also tells you which instance is *active on the UI* (the most recently
modified one).

## Gotcha 4 — traversedpath must list every visited stage in order

When you move the active stage, `traversedpath` is the comma-separated stage GUIDs from the **start
stage through the target**, in order — not just the target. `SetStage` rebuilds it.

**Supported-contract caveat:** Microsoft's documented model is to move only to the **next or
previous** stage (*"Forward navigation of stages must be done in sequence"*). Setting `activestageid`
+ a full `traversedpath` to jump arbitrarily is the **data-migration pattern** — it generally works
for linear flows but is not the officially supported navigation contract.

## Gotcha 5 — Lookup binding: raw Web API vs the Power Automate connector (they differ!)

This is the trap that bit us. The instance's `processid` and `activestageid` are **lookups**. How
you set them depends on the channel:

| Channel | `processid` / `activestageid` | `bpf_<entity>id` |
|---|---|---|
| **Raw Web API** (this skill's script) | `@odata.bind` -> `/workflows(id)`, `/processstages(id)` | `@odata.bind` -> `/incidents(id)` |
| **Power Automate** Dataverse connector | **bare GUID** (the connector surfaces them as uuid strings) | `@odata.bind` -> `/incidents(id)` |

In Power Automate, sending `/workflows(<id>)` to `processid` throws
`OpenApiOperationParameterValidationFailed ... not convertible to String/uuid` — use the bare GUID
there. But against the **raw Web API you MUST use `@odata.bind` for all three** — a bare GUID
property is not a settable OData lookup and the create fails. **Don't carry the connector's
bare-GUID rule into raw Web API calls** (that was a real bug in the first cut of this skill).

## Gotcha 6 — Structural edits are designer-only

Adding, reordering, or renaming **stages** means rewriting the `clientdata` JSON **and** reconciling
the `processstage` rows + GUID references. There is **no supported authoring API**. Do structural
edits in the BPF designer, not via script. This skill covers querying + instance lifecycle + app
wiring only.

## Gotcha 7 — Activation gate

`workflow` (definition) state: `statecode 1 + statuscode 2 = Activated`; `statecode 0 = Draft`. A BPF
must be **Activated** before instances can be created. `CreateInstance` refuses to run against a
Draft BPF.

---

## Worked example — fictitious "Contoso Quote Process"

| Thing | Value |
|---|---|
| BPF (workflow) id | `00aa00aa-bb11-cc22-dd33-44ee44ee44ee` |
| Instance entity | `contoso_quoteprocess` (set `contoso_quoteprocesses`) |
| Primary entity | `incident` |
| Lookup to record | `bpf_incidentid` |
| Start stage | `11bb11bb-cc22-dd33-ee44-55ff55ff55ff` |

Attach the BPF to a record (start stage defaults to the chain head):

```powershell
.\scripts\Invoke-DataverseBPFOperation.ps1 -Operation CreateInstance `
  -EnvironmentUrl "https://contoso.crm.dynamics.com" `
  -BpfName "Contoso Quote Process" -RecordId "<incidentid>" -Interactive
```

Advance the record to a later stage:

```powershell
.\scripts\Invoke-DataverseBPFOperation.ps1 -Operation SetStage `
  -EnvironmentUrl "https://contoso.crm.dynamics.com" `
  -BpfName "Contoso Quote Process" -RecordId "<incidentid>" -StageId "<targetstageid>" -Interactive
```

Make the bar render (one-time per app):

```powershell
.\scripts\Invoke-DataverseBPFOperation.ps1 -Operation AddToApp `
  -EnvironmentUrl "https://contoso.crm.dynamics.com" `
  -BpfName "Contoso Quote Process" -AppUniqueName "Customerservicehub" -Interactive
```
