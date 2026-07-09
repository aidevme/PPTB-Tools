# Solution Component table reference

Reference notes on the Dataverse `solutioncomponent` table, condensed from the
[official table/entity reference](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/reference/entities/solutioncomponent)
for use while working on PCF2BPF. Each `solutioncomponent` row is a membership record: it links one
[solution](./solution.md) (`solutionid`) to one component of a specific type (`componenttype` +
`objectid`) — this is the table that actually enumerates what's *inside* a solution, including BPFs
(`workflow`, type `29`), forms (`systemform`, type `60`), and PCF controls (`customcontrol`, type `66`); see
[Relevance to PCF2BPF](#relevance-to-pcf2bpf) below.

## Entity metadata

| Property | Value |
| --- | --- |
| DisplayName | Solution Component |
| DisplayCollectionName | Solution Components |
| SchemaName | `SolutionComponent` |
| CollectionSchemaName | `SolutionComponents` |
| EntitySetName (Web API) | `solutioncomponents` |
| LogicalName | `solutioncomponent` |
| LogicalCollectionName | `solutioncomponentss` (sic — trailing double "s" per the official reference) |
| PrimaryIdAttribute | `solutioncomponentid` |
| PrimaryNameAttribute | *(none)* |
| TableType | Standard |
| OwnershipType | None |

## Messages

Operations supported on `solutioncomponent`, with their Web API shape. Notably, there is **no** plain
`Create`/`Update`/`Delete`/`Upsert` — components are added to and removed from a solution via the dedicated
`AddSolutionComponent`/`RemoveSolutionComponent` messages instead (which is also why every column below is
read-only; see [Writable columns](#writable-columns)):

| Message | Event? | Web API |
| --- | --- | --- |
| AddSolutionComponent | No | [AddSolutionComponent](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/reference/addsolutioncomponent) |
| RemoveSolutionComponent | No | [RemoveSolutionComponent](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/reference/removesolutioncomponent) |
| UpdateSolutionComponent | No | [UpdateSolutionComponent](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/reference/updatesolutioncomponent) |
| IsComponentCustomizable | No | [IsComponentCustomizable](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/reference/iscomponentcustomizable) |
| Retrieve | No | `GET /solutioncomponents(solutioncomponentid)` |
| RetrieveMultiple | No | `GET /solutioncomponents` |
| Associate / Disassociate | Yes / Yes | [Associate/Disassociate records](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/associate-disassociate-entities-using-web-api) |

## Writable columns

None. Every column on `solutioncomponent` returns `false` for both `IsValidForCreate` and
`IsValidForUpdate` — see [Messages](#messages) above for how membership is actually mutated.

## Read-only columns (`IsValidForCreate` and `IsValidForUpdate` both false)

| SchemaName | LogicalName | Type | Description |
| --- | --- | --- | --- |
| **ComponentType** | `componenttype` | Picklist, required | The object type code of the component — see [ComponentType](#componenttype) below. |
| CreatedBy | `createdby` | Lookup → `systemuser` | User who created the solution component record. |
| CreatedOn | `createdon` | DateTime | When the record was created. |
| CreatedOnBehalfBy | `createdonbehalfby` | Lookup → `systemuser` | Delegate user who created the record. |
| IsMetadata | `ismetadata` | Boolean (default `true`) | Whether this component is metadata (`true`) or data (`false`). |
| ModifiedBy | `modifiedby` | Lookup → `systemuser` | User who last modified the record. |
| ModifiedOn | `modifiedon` | DateTime | When the record was last modified. |
| ModifiedOnBehalfBy | `modifiedonbehalfby` | Lookup → `systemuser` | Delegate user who last modified the record. |
| **ObjectId** | `objectid` | Uniqueidentifier | Unique identifier of the actual component record (e.g. a `workflowid`, `customcontrolid`, `formid`) this row represents. |
| RootComponentBehavior | `rootcomponentbehavior` | Picklist | See [RootComponentBehavior](#rootcomponentbehavior) below. |
| RootSolutionComponentId | `rootsolutioncomponentid` | Uniqueidentifier | Parent id of the subcomponent, which will be a root. |
| SolutionComponentId | `solutioncomponentid` | Uniqueidentifier, required | The `PrimaryIdAttribute`. |
| **SolutionId** | `solutionid` | Lookup → `solution` | The solution this component belongs to. |
| VersionNumber | `versionnumber` | BigInt | Row version number. |

### ComponentType

`componenttype` (Picklist, `componenttype`) identifies what kind of component a `solutioncomponent` row
represents. The full option set is large (Microsoft reuses it across metadata, security, forms, business
logic, integration, and AI component families); the values directly relevant to PCF2BPF are bolded:

| Value | Label |
| --- | --- |
| 1 | Entity |
| 2 | Attribute |
| 3 | Relationship |
| 9 | Option Set |
| 20 | Role |
| **29** | **Workflow** — includes Business Process Flows (`workflow`, `category = 4`; see [workflow.md](./workflow.md)) |
| 36 | Email Template |
| **60** | **System Form** — the `systemform` records this tool reads/writes form XML on |
| 61 | Web Resource |
| **66** | **Custom Control** — PCF controls (`customcontrol`; see [customcontrolresource](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/reference/entities/customcontrolresource)'s many-to-one to `customcontrol`) |
| 68 | Custom Control Default Config |
| 92 | SDK Message Processing Step |
| 300 | Canvas App |
| 380 / 381 | Environment Variable Definition / Value |

See the [official reference](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/reference/entities/solutioncomponent)
for the complete ~90-value list (attribute picklist values, ribbon customizations, SLAs, duplicate rules,
AI projects, etc.) — the rest aren't relevant to BPF form editing.

### RootComponentBehavior

`rootcomponentbehavior` (Picklist, `solutioncomponent_rootcomponentbehavior`):

| Value | Label |
| --- | --- |
| **0** | **Include Subcomponents** |
| 1 | Do not include subcomponents |
| 2 | Include As Shell Only |

## Relationships

### Many-to-one (solutioncomponent → other tables)

| Relationship | solutioncomponent attribute | Referenced table |
| --- | --- | --- |
| lk_solutioncomponentbase_createdonbehalfby | `createdonbehalfby` | `systemuser` |
| lk_solutioncomponentbase_modifiedonbehalfby | `modifiedonbehalfby` | `systemuser` |
| **solution_solutioncomponent** | `solutionid` | `solution` |
| solutioncomponent_parent_solutioncomponent | `rootsolutioncomponentid` | `solutioncomponent` (self-referencing) |

### One-to-many (other tables → solutioncomponent)

| Relationship | Referencing table | Referencing attribute |
| --- | --- | --- |
| solutioncomponent_parent_solutioncomponent | `solutioncomponent` (self-referencing) | `rootsolutioncomponentid` |

No many-to-many relationships are defined on `solutioncomponent`.

## Relevance to PCF2BPF

`services/dataverse.ts`'s `loadBpfProcesses` optionally scopes its `workflow` query to one solution or one
publisher's solutions, by joining through `solutioncomponent` (`componenttype = 29`, the Workflow/BPF
component type) via a FetchXML `<link-entity>`, matching each row's `objectid` against `workflow.workflowid`.
This is triggered from `SolutionsPublishersCard`'s "Load BPFs" button, using whichever solution/publisher is
selected there (see [solution.md](./solution.md)'s Relevance section); `loadPcfControls` is unaffected and
still fetches every registered `customcontrol` regardless of solution.

- Solution-scoped: `solutioncomponent` filtered on `solutionid = <id>` and `componenttype = 29`.
- Publisher-scoped: the same `solutioncomponent` filter, joined one level further to `solution` on
  `publisherid = <id>` — since a publisher can own more than one solution, this query also sets FetchXML's
  `distinct="true"` to dedupe a BPF that appears in more than one of that publisher's solutions.
- To also list only the PCF controls in a given solution (not currently done): same pattern with
  `componenttype = 66`, matching `objectid` against `customcontrol.customcontrolid`.
- `componenttype = 60` (System Form) is the same mechanism for the `systemform` record this tool reads and
  mutates via `services/formxml.ts`, though PCF2BPF locates that record by `objecttypecode` (the BPF's
  private entity), not via `solutioncomponent`.

`objectid` has no declared `Targets` (it's a bare `Uniqueidentifier`, since the target table is implied by
`componenttype`), which is why the queries above hardcode `componenttype = 29` rather than branching on it.
