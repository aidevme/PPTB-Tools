# Solution table reference

Reference notes on the Dataverse `solution` table, condensed from the
[official table/entity reference](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/reference/entities/solution)
for use while working on PCF2BPF. A **solution** is the packaging/deployment unit for Dataverse
customizations — BPFs (`workflow`), PCF controls (`customcontrol`), and forms (`systemform`) are all
typically deployed via a solution, and each carries a `solutionid`/`SolutionId` back-reference to it (see
[Relevance to PCF2BPF](#relevance-to-pcf2bpf) below).

## Entity metadata

| Property | Value |
| --- | --- |
| DisplayName | Solution |
| DisplayCollectionName | Solutions |
| SchemaName | `Solution` |
| CollectionSchemaName | `Solutions` |
| EntitySetName (Web API) | `solutions` |
| LogicalName | `solution` |
| LogicalCollectionName | `solutions` |
| PrimaryIdAttribute | `solutionid` |
| PrimaryNameAttribute | `friendlyname` |
| TableType | Standard |
| OwnershipType | OrganizationOwned |

## Messages

Operations supported on `solution`, with their Web API shape:

| Message | Event? | Web API |
| --- | --- | --- |
| Create | No | `POST /solutions` |
| Update | No | `PATCH /solutions(solutionid)` |
| Upsert | No | `PATCH /solutions(solutionid)` |
| Delete | No | `DELETE /solutions(solutionid)` |
| Retrieve | No | `GET /solutions(solutionid)` |
| RetrieveMultiple | No | `GET /solutions` |
| Associate / Disassociate | Yes / Yes | [Associate/Disassociate records](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/associate-disassociate-entities-using-web-api) |
| CloneAsPatch | No | [CloneAsPatch](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/reference/cloneaspatch) |
| CloneAsSolution | No | [CloneAsSolution](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/reference/cloneassolution) |
| DeleteAndPromote | No | [DeleteAndPromote](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/reference/deleteandpromote) |

## Writable columns (`IsValidForCreate` / `IsValidForUpdate`)

| SchemaName | LogicalName | Type | Description |
| --- | --- | --- | --- |
| ConfigurationPageId | `configurationpageid` | Lookup → `webresource` | Optional configuration page for this solution. |
| Description | `description` | String (TextArea, max 2,000), localizable | Description of the solution. |
| EnabledForSourceControlIntegration | `enabledforsourcecontrolintegration` | Boolean, required | Whether the solution is enabled for source control integration. |
| **FriendlyName** | `friendlyname` | String (max 256), localizable, required | User display name for the solution — the `PrimaryNameAttribute`. |
| PublisherId | `publisherid` | Lookup → `publisher`, required | Publisher of the solution. |
| SolutionId | `solutionid` | Uniqueidentifier, required | The `PrimaryIdAttribute`. |
| SolutionPackageVersion | `solutionpackageversion` | String (VersionNumber, max 256) | Solution package source organization version. |
| SolutionType | `solutiontype` | Picklist | See [SolutionType](#solutiontype). |
| SourceControlSyncStatus | `sourcecontrolsyncstatus` | Picklist, required | See [SourceControlSyncStatus](#sourcecontrolsyncstatus). |
| TemplateSuffix | `templatesuffix` | String (max 65) | The template suffix of this solution. |
| Thumbprint | `thumbprint` | String (max 65), write-only (not valid for read) | Thumbprint of the solution signature. |
| **UniqueName** | `uniquename` | String (max 65), required | The unique name of this solution. |
| Version | `version` | String (VersionNumber, max 256), required | Solution version, used to identify a solution for upgrades and hotfixes. |

### SolutionType

`solutiontype` (Picklist, `solution_solutiontype`):

| Value | Label |
| --- | --- |
| **0** | **None** |
| 1 | Snapshot |
| 2 | Internal |

### SourceControlSyncStatus

`sourcecontrolsyncstatus` (Picklist, `solution_sourcecontrolsyncstatus`):

| Value | Label |
| --- | --- |
| **0** | **Not started** |
| 1 | Initial sync in progress |
| 2 | Errors in initial sync |
| 3 | Pending changes to be committed |
| 4 | Committed |

## Read-only columns (`IsValidForCreate` and `IsValidForUpdate` both false)

| SchemaName | LogicalName | Type | Description |
| --- | --- | --- | --- |
| CreatedBy | `createdby` | Lookup → `systemuser` | User who created the solution. |
| CreatedOn | `createdon` | DateTime | When the solution was created. |
| CreatedOnBehalfBy | `createdonbehalfby` | Lookup → `systemuser` | Delegate user who created the solution. |
| FileId | `fileid` | File (max 128,000 KB), write-only | Blob URL used for file storage; not valid for read either. |
| InstalledOn | `installedon` | DateTime (DateOnly) | When the solution was installed/upgraded. |
| IsApiManaged | `isapimanaged` | Boolean, required | Whether the solution is API-managed. |
| IsInternal | `isinternal` | Boolean, write- and read-only false | Whether the solution is internal. |
| **IsManaged** | `ismanaged` | Boolean | Whether the solution is managed (`true`) or unmanaged (`false`) — the "Package Type". |
| IsVisible | `isvisible` | Boolean (default `true`) | Whether the solution is visible outside of the platform. |
| ModifiedBy | `modifiedby` | Lookup → `systemuser` | User who last modified the solution. |
| ModifiedOn | `modifiedon` | DateTime | When the solution was last modified. |
| ModifiedOnBehalfBy | `modifiedonbehalfby` | Lookup → `systemuser` | Delegate user who last modified the solution. |
| OrganizationId | `organizationid` | Lookup → `organization`, required | Organization associated with the solution. |
| ParentSolutionId | `parentsolutionid` | Lookup → `solution` | Parent solution; non-null only if this solution is a patch. |
| PinpointAssetId | `pinpointassetid` | String (max 255) | Internal — Microsoft Pinpoint asset id. |
| PinpointPublisherId | `pinpointpublisherid` | BigInt | Identifier of the publisher in Microsoft Pinpoint. |
| PinpointSolutionDefaultLocale | `pinpointsolutiondefaultlocale` | String (max 16) | Default locale of the solution in Microsoft Pinpoint. |
| PinpointSolutionId | `pinpointsolutionid` | BigInt | Identifier of the solution in Microsoft Pinpoint. |
| PublisherIdOptionValuePrefix | `publisheridoptionvalueprefix` | Integer | Internal use only. |
| PublisherIdPrefix | `publisheridprefix` | String (max 256) | Internal use only. |
| UpdatedOn | `updatedon` | DateTime | When the solution was updated. |
| UpgradeInfo | `upgradeinfo` | Memo (TextArea, max 1,073,741,823) | Component info for the solution upgrade operation. |
| VersionNumber | `versionnumber` | BigInt | Row version number. |

## Relationships

### Many-to-one (solution → other tables)

| Relationship | solution attribute | Referenced table |
| --- | --- | --- |
| fileattachment_solution_fileid | `fileid` | `fileattachment` |
| lk_solution_createdby | `createdby` | `systemuser` |
| lk_solution_modifiedby | `modifiedby` | `systemuser` |
| lk_solutionbase_createdonbehalfby | `createdonbehalfby` | `systemuser` |
| lk_solutionbase_modifiedonbehalfby | `modifiedonbehalfby` | `systemuser` |
| organization_solution | `organizationid` | `organization` |
| publisher_solution | `publisherid` | `publisher` |
| solution_configuration_webresource | `configurationpageid` | `webresource` |
| solution_parent_solution | `parentsolutionid` | `solution` (self-referencing) |

### One-to-many (other tables → solution)

| Relationship | Referencing table | Referencing attribute |
| --- | --- | --- |
| FileAttachment_Solution | `fileattachment` | `objectid` |
| FK_CanvasApp_Solution | `canvasapp` | `solutionid` |
| solution_fieldpermission | `fieldpermission` | `solutionid` |
| solution_fieldsecurityprofile | `fieldsecurityprofile` | `solutionid` |
| solution_parent_solution | `solution` (self-referencing) | `parentsolutionid` |
| solution_privilege | `privilege` | `solutionid` |
| solution_role | `role` | `solutionid` |
| solution_roleprivileges | `roleprivileges` | `solutionid` |
| **solution_solutioncomponent** | `solutioncomponent` | `solutionid` |
| Solution_SyncErrors | `syncerror` | `regardingobjectid` |
| user_settings_preferred_solution | `usersettings` | `preferredsolution` |

`solution_solutioncomponent` is the relationship that actually enumerates what's *in* a solution: each
`solutioncomponent` row links a `solutionid` to a `componenttype` + `objectid` (the component's own record
id) — this is how a solution's `workflow`/`customcontrol`/`systemform` membership would be resolved, since
those tables don't otherwise expose a direct FetchXML-friendly "which solutions is this component in" path
beyond their own `solutionid` column (see below).

### Many-to-many

| Relationship | Intersect entity |
| --- | --- |
| package_solution | `package_solution` |

## Relevance to PCF2BPF

`services/dataverse.ts` queries `solution` directly in `loadSolutions` (for the "Solutions & Publishers"
picker) and indirectly in `loadBpfProcesses`, which optionally joins through `solutioncomponent` (and, for a
publisher-scoped load, one further join to `solution` on `publisherid`) to scope the BPF list to the
solution/publisher selected in `SolutionsPublishersCard` — see
[solution-component.md](./solution-component.md)'s Relevance section for the FetchXML shape.
`loadPcfControls` still queries `customcontrol` unfiltered by solution.

- `BpfSelector`'s "Load/Reload BPFs" button tooltip tells users to re-click **after importing a solution**
  that adds a new BPF or PCF control, since the list is only fetched on demand — this document exists
  because that guidance implicitly assumes the reader understands what a solution import does.
- Every entity this tool touches — `workflow`, `customcontrol`, `customcontrolresource`, `systemform` — has
  its own read-only `solutionid`/`SolutionId` column pointing back to `solution`, and `customcontrol`/
  `customcontrolresource` also carry `ismanaged`. Only `workflow` is currently solution-scoped (via
  `loadBpfProcesses`' optional `BpfScope`); `customcontrol` filtering (e.g. hiding managed/first-party
  controls, or scoping the PCF control list to one solution) is still open if ever wanted.
- Publishing (`services/dataverse.ts`'s `publishBpf`, via `window.dataverseAPI.publishCustomizations`)
  publishes customizations for the BPF's private entity directly — it doesn't go through solution-level
  publish/import operations (`CloneAsSolution`, etc.), so nothing in this tool currently exercises the
  messages table above.
