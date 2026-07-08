# Workflow (Process) table reference

Reference notes on the Dataverse `workflow` table, condensed from the
[official table/entity reference](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/reference/entities/workflow)
for use while working on PCF2BPF. A **Business Process Flow** is a `workflow` record with
`category = 4` (see [Category](#category) below) — this is the entity `lib/dataverse.ts` queries to find
and load BPF definitions.

## Entity metadata

| Property | Value |
| --- | --- |
| DisplayName | Process |
| DisplayCollectionName | Processes |
| SchemaName | `Workflow` |
| CollectionSchemaName | `Workflows` |
| EntitySetName (Web API) | `workflows` |
| LogicalName | `workflow` |
| LogicalCollectionName | `workflows` |
| PrimaryIdAttribute | `workflowid` |
| PrimaryNameAttribute | `name` |
| TableType | Standard |
| OwnershipType | UserOwned |

## Messages

Operations supported on `workflow`, with their Web API shape:

| Message | Event? | Web API |
| --- | --- | --- |
| Create | No | `POST /workflows` |
| Update | No | `PATCH /workflows(workflowid)` |
| Upsert | No | `PATCH /workflows(workflowid)` |
| Delete | No | `DELETE /workflows(workflowid)` |
| Retrieve | No | `GET /workflows(workflowid)` |
| RetrieveMultiple | No | `GET /workflows` |
| RetrieveUnpublished | Yes | [RetrieveUnpublished](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/reference/retrieveunpublished) |
| RetrieveUnpublishedMultiple | Yes | [RetrieveUnpublishedMultiple](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/reference/retrieveunpublishedmultiple) |
| Assign | No | `PATCH` the `ownerid` property |
| SetState | Yes | `PATCH` the `statecode`/`statuscode` properties |
| Associate / Disassociate | Yes / Yes | [Associate/Disassociate records](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/associate-disassociate-entities-using-web-api) |
| GrantAccess / ModifyAccess / RevokeAccess | No | Sharing operations |
| RetrievePrincipalAccess / RetrieveSharedPrincipalsAndAccess | No | Sharing/access queries |
| ExecuteWorkflow | No | [ExecuteWorkflow](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/reference/executeworkflow) |
| CreateWorkflowFromTemplate | No | [CreateWorkflowFromTemplate](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/reference/createworkflowfromtemplate) |
| InitializeModernFlowFromAsyncWorkflow | No | Flow conversion |
| ListChildDesktopFlows / ListConnectionReferences / RunDesktopFlow / SaveAsDesktopFlow / CancelAllCloudFlowRuns / AddRequiredDesktopFlowComponentsToSolutions / install | No | Cloud/desktop flow management messages, not relevant to BPFs |

## Writable columns (`IsValidForCreate` / `IsValidForUpdate`)

| SchemaName | LogicalName | Type | Description |
| --- | --- | --- | --- |
| AsyncAutoDelete | `asyncautodelete` | Boolean | Indicates whether the asynchronous system job is automatically deleted on completion. |
| BillingContext | `billingcontext` | Memo | Billing context this flow is in. |
| BusinessProcessType | `businessprocesstype` | Picklist | `0` Business Flow, `1` Task Flow. |
| Category | `category` | Picklist | See [Category](#category). |
| Claims | `claims` | Memo | Claims related to this workflow. |
| ClientData | `clientdata` | Memo (max 1,073,741,823) | Business logic converted into client data. |
| ConnectionReferences | `connectionreferences` | Memo | Connection references related to this workflow. |
| CreateMetadata | `createmetadata` | Memo | Create metadata for this workflow. |
| CreateStage | `createstage` | Picklist | `20` Pre-operation, `40` Post-operation. |
| Credentials | `credentials` | Memo | Credentials related to this workflow. |
| Definition | `definition` | Memo (max 16,777,216) | Definition of the business logic of this workflow instance. |
| DeleteStage | `deletestage` | Picklist | `20` Pre-operation, `40` Post-operation. |
| Dependencies | `dependencies` | Memo | Soft dependencies of this workflow instance. |
| Description | `description` | Memo, localizable | Description of the process. |
| DesktopFlowModules | `desktopflowmodules` | Memo | Desktop flow modules related to this workflow. |
| DynamicsSolutionContext | `dynamicssolutioncontext` | Memo | Comma-separated list of Dynamics first-party solution unique names this workflow is in context of. |
| EntityImage | `entityimage` | Image | Default image for the record. |
| FormId | `formid` | Uniqueidentifier | Unique identifier of the associated form. |
| InputParameters | `inputparameters` | Memo (max 1,073,741,823) | Input parameters to the process. |
| Inputs | `inputs` | Memo | Inputs definition for this workflow. |
| IntroducedVersion | `introducedversion` | String (max 48) | Version in which the form is introduced. |
| IsCustomizable | `iscustomizable` | ManagedProperty | Whether this component can be customized. |
| IsCustomProcessingStepAllowedForOtherPublishers | `iscustomprocessingstepallowedforotherpublishers` | ManagedProperty | Whether other publishers can attach custom processing steps to this action. |
| IsTransacted | `istransacted` | Boolean (default `true`) | Whether the steps in the process execute in a single transaction. |
| LanguageCode | `languagecode` | Integer | Language of the process. |
| Licensee | `licensee` | Lookup → `systemuser` | User whose license the flow operates under. |
| LicenseEntitledBy | `licenseentitledby` | Lookup → `workflow` | Source of the license entitlements. |
| Metadata | `metadata` | Memo | Additional metadata for this workflow. |
| Mode | `mode` | Picklist | `0` Background, `1` Real-time. |
| ModernFlowType | `modernflowtype` | Picklist | `0` PowerAutomateFlow, `1` CopilotStudioFlow, `2` M365CopilotAgentFlow. |
| ModifyMetadata | `modifymetadata` | Memo | Flow modify metadata used for telemetry, etc. |
| **Name** | `name` | String (max 100), localizable, required | Name of the process — the `PrimaryNameAttribute`. |
| OnDemand | `ondemand` | Boolean | Whether the process can run as an on-demand process. |
| Outputs | `outputs` | Memo | Outputs definition for this workflow. |
| OwnerId | `ownerid` | Owner → `systemuser`, required | Owner of the process. |
| OwnerIdType | `owneridtype` | EntityName, required | — |
| PlanVerified | `planverified` | Boolean | Internal use only. |
| PrimaryEntity | `primaryentity` | EntityName, required | Primary entity for the process; the process can be associated with SDK operations defined on it. |
| ProcessOrder | `processorder` | Integer | Business process flow step order. |
| ProcessRoleAssignment | `processroleassignment` | Memo (max 1,048,576) | Role assignment for the process. |
| ProcessTriggerFormId | `processtriggerformid` | Uniqueidentifier | Associated form for the process trigger. |
| ProcessTriggerScope | `processtriggerscope` | Picklist | `1` Form, `2` Entity. |
| Rank | `rank` | Integer | Order of execution for the synchronous workflow. |
| RendererObjectTypeCode | `rendererobjecttypecode` | EntityName | Renderer type of the workflow. |
| ResourceContainer | `resourcecontainer` | String | Internal use only. |
| ResourceId | `resourceid` | Uniqueidentifier | Internal use only. |
| RunAs | `runas` | Picklist (default `1`) | `0` Owner, `1` Calling User. |
| SchemaVersion | `schemaversion` | String (max 100) | Schema version for this workflow. |
| Scope | `scope` | Picklist, required | `1` User, `2` Business Unit, `3` Parent: Child Business Units, `4` Organization. |
| **StateCode** | `statecode` | State, required | See [StateCode](#statecode-and-statuscode). |
| **StatusCode** | `statuscode` | Status | See [StateCode](#statecode-and-statuscode). |
| Subprocess | `subprocess` | Boolean | Whether the process can be included in other processes as a child process. |
| SuspensionReasonDetails | `suspensionreasondetails` | Memo (max 500) | — |
| SyncWorkflowLogOnFailure | `syncworkflowlogonfailure` | Boolean, required | Whether synchronous workflow failures are saved to log files. |
| ThrottlingBehavior | `throttlingbehavior` | Picklist | `0` None, `1` TenantPool, `2` CopilotStudio. |
| TriggerOnCreate | `triggeroncreate` | Boolean | Whether the process triggers when the primary entity is created. |
| TriggerOnDelete | `triggerondelete` | Boolean | Whether the process triggers on deletion of the primary entity. |
| TriggerOnUpdateAttributeList | `triggeronupdateattributelist` | Memo (max 1,073,741,823) | Attributes that trigger the process when updated. |
| Type | `type` | Picklist, required | `1` Definition, `2` Activation, `3` Template. |
| UIFlowType | `uiflowtype` | Picklist | `0` Windows recorder (V1), `1` Selenium IDE, `2` Power Automate Desktop, `3` Test, `101` Recording. |
| **UniqueName** | `uniquename` | String (max 256) | Unique name of the process — used to derive the BPF's private entity logical name (see below). |
| UpdateStage | `updatestage` | Picklist | `20` Pre-operation, `40` Post-operation. |
| WorkflowId | `workflowid` | Uniqueidentifier, required | The `PrimaryIdAttribute`. |
| Xaml | `xaml` | Memo (max 1,073,741,823), required | XAML that defines the process. |

### Category

`category` (Picklist, `workflow_category`) identifies what kind of process a `workflow` record is:

| Value | Label |
| --- | --- |
| 0 | Workflow |
| 1 | Dialog |
| 2 | Business Rule |
| 3 | Action |
| **4** | **Business Process Flow** |
| 5 | Modern Flow |
| 6 | Desktop Flow |
| 7 | AI Flow |

PCF2BPF filters on `category = 4` to enumerate BPFs (`lib/dataverse.ts`).

### StateCode and StatusCode

| StateCode | Label | Valid StatusCode |
| --- | --- | --- |
| 0 | Draft | 1 (Draft) |
| 1 | Activated | 2 (Activated) |
| 2 | Suspended | 3 (CompanyDLPViolation) |

Only `Activated` BPFs have a usable form; PCF2BPF should generally read the activated
(`statecode = 1`) workflow when resolving a BPF's form.

## Read-only columns (`IsValidForCreate` and `IsValidForUpdate` both false)

| SchemaName | LogicalName | Type | Description |
| --- | --- | --- | --- |
| ActiveWorkflowId | `activeworkflowid` | Lookup → `workflow` | Latest activation record for the process. |
| ClientDataIsCompressed | `clientdataiscompressed` | Boolean | Internal use only. |
| ComponentState | `componentstate` | Picklist | `0` Published, `1` Unpublished, `2` Deleted, `3` Deleted Unpublished. |
| CreatedBy | `createdby` | Lookup → `systemuser` | User who created the process. |
| CreatedOn | `createdon` | DateTime | When the process was created. |
| CreatedOnBehalfBy | `createdonbehalfby` | Lookup → `systemuser` | Delegate user who created the process. |
| EntityImage_Timestamp | `entityimage_timestamp` | BigInt | — |
| EntityImage_URL | `entityimage_url` | String (Url) | — |
| EntityImageId | `entityimageid` | Uniqueidentifier | Internal use only. |
| IsCrmUIWorkflow | `iscrmuiworkflow` | Boolean | Whether the process was created using the web application. |
| IsManaged | `ismanaged` | Boolean | Whether the solution component is part of a managed solution. |
| ModifiedBy | `modifiedby` | Lookup → `systemuser` | User who last modified the process. |
| ModifiedOn | `modifiedon` | DateTime | When the process was last modified. |
| ModifiedOnBehalfBy | `modifiedonbehalfby` | Lookup → `systemuser` | Delegate user who last modified the process. |
| OverwriteTime | `overwritetime` | DateTime | Internal use only. |
| OwnerIdName / OwnerIdYomiName | `owneridname` / `owneridyominame` | String | Cached name of `ownerid`. |
| OwningBusinessUnit | `owningbusinessunit` | Lookup → `businessunit` | Business unit that owns the process. |
| OwningTeam | `owningteam` | Lookup → `team` | Team that owns the process. |
| OwningUser | `owninguser` | Lookup → `systemuser` | User that owns the process. |
| ParentWorkflowId | `parentworkflowid` | Lookup → `workflow` | Definition record for a process activation. |
| PluginTypeId | `plugintypeid` | Lookup → `sdkmessagefilter` | Associated plug-in type. |
| SdkMessageId | `sdkmessageid` | Lookup → `sdkmessage` | Associated SDK message. |
| SolutionId | `solutionid` | Uniqueidentifier | Associated solution. |
| SupportingSolutionId | `supportingsolutionid` | Uniqueidentifier | Internal use only; not valid for read. |
| TrustedAccess | `trustedaccess` | Boolean | Internal use only. |
| UIData | `uidata` | Memo (max 1,073,741,823) | Internal use only. |
| VersionNumber | `versionnumber` | BigInt | Row version number. |
| WorkflowIdUnique | `workflowidunique` | Uniqueidentifier, required | Internal use only. |

## Relationships

### Many-to-one (workflow → other tables)

| Relationship | workflow attribute | Referenced table |
| --- | --- | --- |
| business_unit_workflow | `owningbusinessunit` | `businessunit` |
| owner_workflows | `ownerid` | `owner` |
| system_user_workflow | `owninguser` | `systemuser` |
| team_workflow | `owningteam` | `team` |
| workflow_active_workflow | `activeworkflowid` | `workflow` |
| workflow_createdby | `createdby` | `systemuser` |
| workflow_createdonbehalfby | `createdonbehalfby` | `systemuser` |
| Workflow_licensee | `licensee` | `systemuser` |
| Workflow_licenseentitledby | `licenseentitledby` | `workflow` |
| workflow_modifiedby | `modifiedby` | `systemuser` |
| workflow_modifiedonbehalfby | `modifiedonbehalfby` | `systemuser` |
| workflow_parent_workflow | `parentworkflowid` | `workflow` |

### One-to-many (other tables → workflow), selected entries relevant to forms/processes

| Relationship | Referencing table | Referencing attribute |
| --- | --- | --- |
| process_processstage | `processstage` | `processid` |
| process_processtrigger | `processtrigger` | `processid` |
| workflow_businessprocess | `businessprocess` | `rootworkflowid` |
| Workflow_Annotation | `annotation` | `objectid` |
| workflow_flowrun_Workflow | `flowrun` | `workflow` |
| workflow_flowlog_cloudflowid / workflow_flowlog_desktopflowid | `flowlog` | `cloudflowid` / `desktopflowid` |
| lk_processsession_processid | `processsession` | `processid` |
| lk_expiredprocess_processid | `expiredprocess` | `processid` |
| lk_newprocess_processid | `newprocess` | `processid` |
| workflowmetadata_WorkflowId_workflow | `workflowmetadata` | `workflowid` |
| workflow_workflowbinary_Process | `workflowbinary` | `process` |
| workflow_desktopflowbinary_Process | `desktopflowbinary` | `process` |

The full one-to-many list also includes AI/Copilot, SLA, licensing, and solution-health
relationships (`AIPluginOperation_Workflow_Workflow`, `slabase_workflowid`,
`slaitembase_workflowid`, `msdyn_*` rows, `Workflow_SyncErrors`, etc.) — see the
[source reference](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/reference/entities/workflow)
for the complete set; they aren't relevant to BPF form editing.

### Many-to-many

| Relationship | Intersect entity |
| --- | --- |
| botcomponent_workflow | `botcomponent_workflow` |
| workflow_card_connections | `workflowcardconnections` |

## Relevance to PCF2BPF

- `lib/dataverse.ts` queries `workflow` filtered on `category = 4` (and typically `statecode = 1`)
  to list/load BPFs by `name`/`uniquename` and `workflowid`.
- A BPF's `uniquename` names its private entity; that entity's `ObjectTypeCode` is looked up via
  entity metadata, which is then used to find the sole `systemform` record whose `objecttypecode`
  matches it — that `systemform.formxml` is what `lib/formxml.ts` parses and mutates.
- None of PCF2BPF's mutations write back to `workflow` itself; only the related `systemform` row is
  updated (via its own `Update` message) once PCF assignments change.
