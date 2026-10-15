---
name: hso-dataverse-bpf
layer: atomic
scope: core
description: 'Query, instantiate, and drive Dataverse Business Process Flows (BPFs) via the Web API: resolve a BPF and its true stage order, create/list/advance instances on a record, and add a BPF to an app so its bar renders. Use when attaching a BPF to records, driving stages from code/flows, or debugging a blank BPF. Does NOT edit BPF structure (designer-only).'
---

# Dataverse Business Process Flows (BPF)

Programmatic BPF lifecycle: resolve a BPF, read its stages **in true order**, create and move
instances on records, and wire the BPF into an app so the process bar actually renders. Built from
the gotchas that make BPF automation painful — see
[references/bpf-internals.md](references/bpf-internals.md) for the full data model and the traps.

## When to use this skill

- Attaching a BPF to a record from code or a Power Automate flow (create the instance, set start stage)
- Advancing / retarding a BPF stage as a status field changes (forward **and** backward)
- A BPF "doesn't show on the form / is blank" — diagnosing app-inclusion and instance state
- Reading a BPF's stages in their real left-to-right order, or dumping its `clientdata`
- Listing the BPF instances on a given record

## When NOT to use this skill

- **Editing BPF structure** (add / reorder / rename stages, change bound fields). There is no
  supported authoring API — use the BPF designer. This skill is read + instance-lifecycle + app-wiring only.
- Classic workflows, actions, or modern (cloud) flows — this is BPF (`workflow` category = 4) only.
- **Branched BPFs.** Stage ordering is parsed from a single linear clientdata `nextStageId` chain;
  conditional/branched flows aren't handled. Use the `RetrieveActivePath` / `RetrieveProcessInstances`
  messages for those (see references Gotcha 3).

## Configuration

Read from `CLAUDE.md`: **Environment URL** · **Publisher Prefix** · **Default Solution**
Auth uses the shared `Dataverse-Auth.ps1` (interactive, auto-falls-back to device-code when the
embedded WebView renders blank; pass `-DeviceCode` to force it).

## The three-part model (read this first)

| Part | Entity | Role |
|---|---|---|
| Definition | `workflow` (category 4) | holds `clientdata`, `uniquename`, `primaryentity`, state |
| Stages | `processstage` | one row per stage — **unordered** when queried |
| **Instance** | `<workflow.uniquename>` | one row per record — **the source of truth** for the active stage |

The instance entity logical name **is** the workflow's `uniquename`. Its key lookups: `processid`
(→workflow), `activestageid` (→processstage), `bpf_<primaryentity>id` (→the record), plus
`traversedpath`.

## Critical rules (DO / DON'T)

- ❌ **DON'T** PATCH `processid` / `stageid` / `traversedpath` on the **primary record** — those
  writes return 204 but silently persist nothing. Drive the **instance row** instead.
- ❌ **DON'T** trust `processstage` query order — derive stage order from `clientdata`'s
  `nextStageId` chain (this skill does it for you).
- ✅ **DO** add the BPF to the model-driven app (`AddToApp`) — a valid instance alone renders blank
  if the BPF isn't an app component.
- ✅ **DO** mind the binding channel: against the **raw Web API** (this skill's script) set ALL
  lookups via `@odata.bind` (`processid`/`activestageid`/`bpf_<entity>id`). In the **Power Automate
  connector** ONLY, `processid`/`activestageid` are bare-GUID uuid fields while the record lookup is
  still a bind. Don't carry the connector's bare-GUID rule into raw Web API calls.
- ✅ **DO** ensure the BPF is **Activated** (`statecode 1 + statuscode 2`) before creating instances.

## Operations

All operations run through one script:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-bpf/scripts/Invoke-DataverseBPFOperation.ps1" `
    -Operation <Name> -EnvironmentUrl "https://<org>.crm.dynamics.com" -Interactive <params>
```

| Operation | Key params | Purpose |
|---|---|---|
| `QueryBPF` | `-BpfId` or `-BpfName` | Resolve a BPF; decode state; report instance entity + lookup field |
| `QueryStages` | `-BpfId`/`-BpfName` | List stages **in true order** (from clientdata), with bound data field + start stage |
| `GetClientData` | `-BpfId`/`-BpfName` `[-OutFile]` | Save `clientdata` to a file and print the stage chain |
| `ListInstances` | `-BpfName` `-RecordId` | List BPF instances on a record |
| `CreateInstance` | `-BpfName` `-RecordId` `[-StageId]` | Attach the BPF to a record (defaults to the start stage) |
| `SetStage` | `-BpfName` `-RecordId`/`-InstanceId` `-StageId` | Move the active stage; rebuilds `traversedpath` |
| `AddToApp` | `-BpfName` `-AppUniqueName` | Add the BPF to an app (REQUIRED for the bar to render) |
| `QueryAppInclusion` | `-BpfName` | Report which apps include the BPF |

### Examples

```powershell
# What are the stages, in order, and what is the start stage?
... -Operation QueryStages -BpfName "Contoso Quote Process" -Interactive

# Attach the BPF to a case (start stage = chain head)
... -Operation CreateInstance -BpfName "Contoso Quote Process" -RecordId "<incidentid>" -Interactive

# Advance/retard the case to a specific stage (traversedpath rebuilt automatically)
... -Operation SetStage -BpfName "Contoso Quote Process" -RecordId "<incidentid>" -StageId "<stageid>" -Interactive

# Make the bar render: add the BPF to the app the user opens records in
... -Operation AddToApp -BpfName "Contoso Quote Process" -AppUniqueName "Customerservicehub" -Interactive

# Debug "BPF is blank": is it even in any app?
... -Operation QueryAppInclusion -BpfName "Contoso Quote Process" -Interactive
```

## Diagnosing "the BPF doesn't show / is blank"

Several causes — work them in this order (most common first):

1. **Security roles.** The BPF instance table defaults to **System Administrator / Customizer only**.
   For any other role the bar vanishes silently — enable roles (designer → Edit security roles).
2. `ListInstances` — is there an **active** instance on the record? If not → create one.
3. `QueryAppInclusion` — "NOT IN ANY APP" → `AddToApp`, publish, reload (likely fix, not certain).
4. Append **`&monitor=true`** to the record URL to launch the **BPF Monitor** — it reports the actual
   reason the flow isn't rendering.
5. **Don't** try to "fix" it by writing the record's `processid`/`stageid` — that's a deprecated,
   unsupported, silently-dropped write (the only sanctioned write is `processid` at create-time).

## Power Automate note

To instantiate a BPF in a flow, "Add a new row" on the **instance table** with: `processid` = bare
BPF GUID, `activestageid` = bare start-stage GUID, `bpf_<entity>id` = `/<entityset>(<recordid>)`.
This bare-GUID form is **connector-specific** — the raw Web API (this skill's script) needs
`@odata.bind` for all three. Do **not** add a step that writes the record's process pointers — it's
a silent no-op. See [references/bpf-internals.md](references/bpf-internals.md) Gotcha 5.

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
