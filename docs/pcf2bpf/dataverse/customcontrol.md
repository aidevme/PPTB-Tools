# Custom Control (`customcontrol`) table reference

Source: [Custom Control (CustomControl) table/entity reference](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/reference/entities/customcontrol) (Microsoft Learn)

The `customcontrol` table stores registered PCF (PowerApps Component Framework) controls in a Dataverse
environment. PCF2BPF queries this table (see `services/dataverse.ts`) to list controls available for
assignment to BPF fields, using `compatibledatatypes` to filter by field type and `manifest` (XML) to read
the control's configurable parameters.

## Messages

Operations that can be performed on the table.

| Message | Event? | Web API operation | SDK for .NET |
| --- | --- | --- | --- |
| `Associate` | Yes | [Associate records](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/associate-disassociate-entities-using-web-api) | [Associate records](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/org-service/entity-operations-associate-disassociate#use-the-associate-method-or-associaterequest) |
| `Create` | Yes | `POST /customcontrols` — [Create](https://learn.microsoft.com/en-us/powerapps/developer/data-platform/webapi/create-entity-web-api) | [Create records](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/org-service/entity-operations-create#basic-create) |
| `Delete` | Yes | `DELETE /customcontrols(customcontrolid)` — [Delete](https://learn.microsoft.com/en-us/powerapps/developer/data-platform/webapi/update-delete-entities-using-web-api#basic-delete) | [Delete records](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/org-service/entity-operations-update-delete#basic-delete) |
| `Disassociate` | Yes | [Disassociate records](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/associate-disassociate-entities-using-web-api) | [Disassociate records](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/org-service/entity-operations-associate-disassociate#use-the-disassociate-method-or-disassociaterequest) |
| `Retrieve` | Yes | `GET /customcontrols(customcontrolid)` — [Retrieve](https://learn.microsoft.com/en-us/powerapps/developer/data-platform/webapi/retrieve-entity-using-web-api) | [Retrieve records](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/org-service/entity-operations-retrieve) |
| `RetrieveMultiple` | Yes | `GET /customcontrols` — [Query data](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/query-data-web-api) | [Query data](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/org-service/entity-operations-query-data) |
| `Update` | Yes | `PATCH /customcontrols(customcontrolid)` — [Update](https://learn.microsoft.com/en-us/powerapps/developer/data-platform/webapi/update-delete-entities-using-web-api#basic-update) | [Update records](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/org-service/entity-operations-update-delete#basic-update) |
| `Upsert` | No | `PATCH /customcontrols(customcontrolid)` — [Upsert a table row](https://learn.microsoft.com/en-us/powerapps/developer/data-platform/webapi/update-delete-entities-using-web-api#upsert-a-table-row) | [UpsertRequest](https://learn.microsoft.com/en-us/dotnet/api/microsoft.xrm.sdk.messages.upsertrequest) |

## Table properties

| Property | Value |
| --- | --- |
| DisplayName | Custom Control |
| DisplayCollectionName | Custom Controls |
| SchemaName | `CustomControl` |
| CollectionSchemaName | `CustomControls` |
| EntitySetName | `customcontrols` |
| LogicalName | `customcontrol` |
| LogicalCollectionName | `customcontrols` |
| PrimaryIdAttribute | `customcontrolid` |
| PrimaryNameAttribute | `name` |
| TableType | Standard |
| OwnershipType | OrganizationOwned |

## Writable columns/attributes

Columns where `IsValidForCreate` and/or `IsValidForUpdate` is `true`.

### AuthoringManifest

| Property | Value |
| --- | --- |
| Description | Authoring Manifest of the CustomControl. |
| DisplayName | Authoring Manifest |
| LogicalName | `authoringmanifest` |
| Type | Memo |
| Format | TextArea |
| RequiredLevel | None |
| MaxLength | 1,073,741,823 |
| IsValidForForm | False |

### ClientJson

| Property | Value |
| --- | --- |
| Description | Custom control data in JSON format. |
| LogicalName | `clientjson` |
| Type | Memo |
| Format | TextArea |
| RequiredLevel | None |
| MaxLength | 1,073,741,823 |
| IsValidForForm | False |

### CompatibleDataTypes

| Property | Value |
| --- | --- |
| Description | Compatible Data Types For Custom Controls |
| LogicalName | `compatibledatatypes` |
| Type | String |
| Format | Text |
| RequiredLevel | SystemRequired |
| MaxLength | 1,000 |
| IsValidForForm | False |

Comma-separated list of field/attribute types the control can bind to (e.g. `SingleLine.Text`,
`OptionSetType.Boolean`) — this is what PCF2BPF filters on to only show controls compatible with the
selected BPF field's type.

### CustomControlId

| Property | Value |
| --- | --- |
| Description | Unique identifier of the Custom Control for the Microsoft Dynamics 365. |
| DisplayName | Custom Control Identifier |
| LogicalName | `customcontrolid` |
| Type | Uniqueidentifier |
| RequiredLevel | SystemRequired |
| IsValidForForm | False |

### IntroducedVersion

| Property | Value |
| --- | --- |
| Description | Version in which the form is introduced. |
| DisplayName | Introduced Version |
| LogicalName | `introducedversion` |
| Type | String |
| Format | VersionNumber |
| RequiredLevel | None |
| MaxLength | 48 |
| IsValidForForm | False |

### Manifest

| Property | Value |
| --- | --- |
| Description | Manifest of the CustomControl. |
| DisplayName | Manifest |
| LogicalName | `manifest` |
| Type | Memo |
| Format | TextArea |
| RequiredLevel | SystemRequired |
| MaxLength | 1,073,741,823 |
| IsValidForForm | False |

XML manifest describing the control, including its `<property>` definitions — PCF2BPF's
`services/pcfManifest.ts` parses this to build the parameter list shown in the UI.

### Name

| Property | Value |
| --- | --- |
| Description | Name of the custom control. |
| DisplayName | Name |
| LogicalName | `name` |
| Type | String |
| Format | Text |
| RequiredLevel | SystemRequired |
| MaxLength | 200 |
| IsValidForForm | False |

### SupportedPlatform

| Property | Value |
| --- | --- |
| Description | Supported platforms of the CustomControl. |
| DisplayName | Supported Platforms |
| LogicalName | `supportedplatform` |
| Type | String |
| Format | Text |
| RequiredLevel | None |
| MaxLength | 100 |
| IsValidForForm | False |

### Version

| Property | Value |
| --- | --- |
| Description | For internal use only. |
| LogicalName | `version` |
| Type | String |
| Format | Text |
| RequiredLevel | SystemRequired |
| MaxLength | 40 |
| IsValidForForm | False |

## Read-only columns/attributes

Columns where both `IsValidForCreate` and `IsValidForUpdate` are `false`.

### ComponentState

| Property | Value |
| --- | --- |
| LogicalName | `componentstate` |
| Type | Picklist |
| RequiredLevel | SystemRequired |
| DefaultFormValue | -1 |
| GlobalChoiceName | `componentstate` |

| Value | Label |
| --- | --- |
| 0 | Published |
| 1 | Unpublished |
| 2 | Deleted |
| 3 | Deleted Unpublished |

### CreatedBy

| Property | Value |
| --- | --- |
| Description | Unique identifier of the user who created the record. |
| LogicalName | `createdby` |
| Type | Lookup |
| Targets | `systemuser` |
| RequiredLevel | None |

### CreatedOn

| Property | Value |
| --- | --- |
| Description | Date and time when the record was created. |
| LogicalName | `createdon` |
| Type | DateTime |
| Format | DateAndTime |
| DateTimeBehavior | UserLocal |
| RequiredLevel | None |

### CreatedOnBehalfBy

| Property | Value |
| --- | --- |
| Description | Unique identifier of the delegate user who created the record. |
| LogicalName | `createdonbehalfby` |
| Type | Lookup |
| Targets | `systemuser` |
| RequiredLevel | None |

### CustomControlIdUnique

| Property | Value |
| --- | --- |
| Description | For internal use only. |
| LogicalName | `customcontrolidunique` |
| Type | Uniqueidentifier |
| RequiredLevel | SystemRequired |

### IsManaged

| Property | Value |
| --- | --- |
| LogicalName | `ismanaged` |
| Type | Boolean |
| GlobalChoiceName | `ismanaged` |
| DefaultValue | False |
| True label | Managed |
| False label | Unmanaged |
| RequiredLevel | SystemRequired |

### ModifiedBy

| Property | Value |
| --- | --- |
| Description | Unique identifier of the user who modified the record. |
| LogicalName | `modifiedby` |
| Type | Lookup |
| Targets | `systemuser` |
| RequiredLevel | None |

### ModifiedOn

| Property | Value |
| --- | --- |
| Description | Date and time when the record was modified. |
| LogicalName | `modifiedon` |
| Type | DateTime |
| Format | DateAndTime |
| DateTimeBehavior | UserLocal |
| RequiredLevel | None |

### ModifiedOnBehalfBy

| Property | Value |
| --- | --- |
| Description | Unique identifier of the delegate user who modified the record. |
| LogicalName | `modifiedonbehalfby` |
| Type | Lookup |
| Targets | `systemuser` |
| RequiredLevel | None |

### OrganizationId

| Property | Value |
| --- | --- |
| Description | Unique identifier of the organization associated with the custom control. |
| LogicalName | `organizationid` |
| Type | Lookup |
| Targets | `organization` |
| RequiredLevel | SystemRequired |

### OverwriteTime

| Property | Value |
| --- | --- |
| Description | For internal use only. |
| DisplayName | Record Overwrite Time |
| LogicalName | `overwritetime` |
| Type | DateTime |
| Format | DateOnly |
| DateTimeBehavior | UserLocal |
| RequiredLevel | SystemRequired |

### SolutionId

| Property | Value |
| --- | --- |
| Description | Unique identifier of the associated solution. |
| LogicalName | `solutionid` |
| Type | Uniqueidentifier |
| RequiredLevel | SystemRequired |

### SupportingSolutionId

| Property | Value |
| --- | --- |
| Description | For internal use only. |
| LogicalName | `supportingsolutionid` |
| Type | Uniqueidentifier |
| RequiredLevel | None |
| IsValidForRead | False |

### VersionNumber

| Property | Value |
| --- | --- |
| Description | Version number of the Custom Control. |
| DisplayName | Version Number |
| LogicalName | `versionnumber` |
| Type | BigInt |
| MaxValue | 9,223,372,036,854,775,807 |
| MinValue | -9,223,372,036,854,775,808 |
| RequiredLevel | None |

## Relationships

### Many-to-one

| Schema name | Referenced entity | Referencing attribute |
| --- | --- | --- |
| `customcontrol_organization` | `organization` | `organizationid` |
| `lk_customcontrol_createdby` | `systemuser` | `createdby` |
| `lk_customcontrol_createdonbehalfby` | `systemuser` | `createdonbehalfby` |
| `lk_customcontrol_modifiedby` | `systemuser` | `modifiedby` |
| `lk_customcontrol_modifiedonbehalfby` | `systemuser` | `modifiedonbehalfby` |

All five use `NoCascade` for Archive/Assign/Delete/Merge/Reparent/RollupView/Share/Unshare.

### One-to-many

| Schema name | Referencing entity | Referencing attribute |
| --- | --- | --- |
| `customcontrol_resource_id` | `customcontrolresource` | `customcontrolid` |

### Many-to-many

| Schema name | Intersect entity | Intersect attribute |
| --- | --- | --- |
| `serviceplan_customcontrol` | `serviceplancustomcontrol` | `customcontrolid` |

## See also

- [Dataverse table/entity reference](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/reference/about-entity-reference)
- [Dataverse Web API reference: customcontrol](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/reference/customcontrol)
