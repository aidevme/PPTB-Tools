# Publisher table reference

Reference notes on the Dataverse `publisher` table, condensed from the
[official table/entity reference](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/reference/entities/publisher)
for use while working on PCF2BPF. A **publisher** is the organization/individual that owns a
[solution](./solution.md) (`publisher_solution`); its `customizationprefix` is where the `msdyn_`/`new_`/etc.
prefixes seen throughout Dataverse logical names — including in this tool's own field/entity names — come
from (see [Relevance to PCF2BPF](#relevance-to-pcf2bpf) below).

## Entity metadata

| Property | Value |
| --- | --- |
| DisplayName | Publisher |
| DisplayCollectionName | Publishers |
| SchemaName | `Publisher` |
| CollectionSchemaName | `Publishers` |
| EntitySetName (Web API) | `publishers` |
| LogicalName | `publisher` |
| LogicalCollectionName | `publishers` |
| PrimaryIdAttribute | `publisherid` |
| PrimaryNameAttribute | `friendlyname` |
| TableType | Standard |
| OwnershipType | OrganizationOwned |

## Messages

Operations supported on `publisher`, with their Web API shape:

| Message | Event? | Web API |
| --- | --- | --- |
| Create | No | `POST /publishers` |
| Update | No | `PATCH /publishers(publisherid)` |
| Upsert | No | `PATCH /publishers(publisherid)` |
| Delete | No | `DELETE /publishers(publisherid)` |
| Retrieve | No | `GET /publishers(publisherid)` |
| RetrieveMultiple | No | `GET /publishers` |
| Associate / Disassociate | Yes / Yes | [Associate/Disassociate records](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/associate-disassociate-entities-using-web-api) |

## Writable columns (`IsValidForCreate` / `IsValidForUpdate`)

| SchemaName | LogicalName | Type | Description |
| --- | --- | --- | --- |
| CustomizationOptionValuePrefix | `customizationoptionvalueprefix` | Integer (10,000–99,999), required | Default option-set value prefix used for new options in solutions associated with this publisher. |
| **CustomizationPrefix** | `customizationprefix` | String (max 8), required | Prefix used for new entities, attributes, and relationships in solutions associated with this publisher — see [Relevance to PCF2BPF](#relevance-to-pcf2bpf). |
| Description | `description` | String (TextArea, max 2,000), localizable | Description of the publisher. |
| EMailAddress | `emailaddress` | String (Email, max 100) | Email address for the publisher. |
| EntityImage | `entityimage` | Image (max 144×144, 10,240 KB), primary image | Default image for the record. |
| **FriendlyName** | `friendlyname` | String (max 256), localizable, required | User display name for this publisher — the `PrimaryNameAttribute`. |
| PublisherId | `publisherid` | Uniqueidentifier, required | The `PrimaryIdAttribute`. |
| SupportingWebsiteUrl | `supportingwebsiteurl` | String (Url, max 200) | URL for the publisher's supporting website. |
| **UniqueName** | `uniquename` | String (max 256), required | The unique name of this publisher. |

### Address columns (`address1_*` / `address2_*`)

Publisher carries two full address blocks (Address 1 / Address 2), each exposing the same set of fields —
only the `DisplayName` prefix and `address1_`/`address2_` logical-name prefix differ:

| Field | LogicalName suffix | Type | Description |
| --- | --- | --- | --- |
| Address ID | `addressid` | Uniqueidentifier (read-only) | Unique identifier for this address. |
| Address Type | `addresstypecode` | Picklist (`publisher_addressN_addresstypecode`) | Only defined option: `1` Default Value. |
| City | `city` | String (max 80) | City name. |
| Country/Region | `country` | String (max 80) | Country/region name. |
| County | `county` | String (max 50) | County name. |
| Fax | `fax` | String (max 50) | Fax number. |
| Latitude | `latitude` | Double (±90, precision 5) | Latitude. |
| Longitude | `longitude` | Double (±180, precision 5) | Longitude. |
| Name | `name` | String (max 100) | Name for this address. |
| Street 1 / 2 / 3 | `line1` / `line2` / `line3` | String (max 50) | Street address lines. |
| ZIP/Postal Code | `postalcode` | String (max 20) | ZIP or postal code. |
| Post Office Box | `postofficebox` | String (max 20) | PO box number. |
| Shipping Method | `shippingmethodcode` | Picklist (`publisher_addressN_shippingmethodcode`) | Only defined option: `1` Default Value. |
| State/Province | `stateorprovince` | String (max 50) | State or province. |
| Telephone 1 / 2 / 3 | `telephone1` / `telephone2` / `telephone3` | String (max 50) | Phone numbers. |
| UPS Zone | `upszone` | String (max 4) | United Parcel Service zone. |
| UTC Offset | `utcoffset` | Integer (±1500) | Difference between local time and UTC. |

## Read-only columns (`IsValidForCreate` and `IsValidForUpdate` both false)

| SchemaName | LogicalName | Type | Description |
| --- | --- | --- | --- |
| CreatedBy | `createdby` | Lookup → `systemuser` | User who created the publisher. |
| CreatedOn | `createdon` | DateTime | When the publisher was created. |
| CreatedOnBehalfBy | `createdonbehalfby` | Lookup → `systemuser` | Delegate user who created the publisher. |
| EntityImage_Timestamp | `entityimage_timestamp` | BigInt | — |
| EntityImage_URL | `entityimage_url` | String (Url) | — |
| EntityImageId | `entityimageid` | Uniqueidentifier | Internal use only. |
| **IsReadonly** | `isreadonly` | Boolean, required | Whether the publisher was created as part of a managed solution installation. |
| ModifiedBy | `modifiedby` | Lookup → `systemuser` | User who last modified the publisher. |
| ModifiedOn | `modifiedon` | DateTime | When the publisher was last modified. |
| ModifiedOnBehalfBy | `modifiedonbehalfby` | Lookup → `systemuser` | Delegate user who last modified the publisher. |
| OrganizationId | `organizationid` | Lookup → `organization`, required | Organization associated with the publisher. |
| PinpointPublisherDefaultLocale | `pinpointpublisherdefaultlocale` | String (max 16) | Default locale of the publisher in Microsoft Pinpoint. |
| PinpointPublisherId | `pinpointpublisherid` | BigInt | Identifier of the publisher in Microsoft Pinpoint. |
| VersionNumber | `versionnumber` | BigInt | Row version number. |

## Relationships

### Many-to-one (publisher → other tables)

| Relationship | publisher attribute | Referenced table |
| --- | --- | --- |
| lk_publisher_createdby | `createdby` | `systemuser` |
| lk_publisher_modifiedby | `modifiedby` | `systemuser` |
| lk_publisherbase_createdonbehalfby | `createdonbehalfby` | `systemuser` |
| lk_publisherbase_modifiedonbehalfby | `modifiedonbehalfby` | `systemuser` |
| organization_publisher | `organizationid` | `organization` |

### One-to-many (other tables → publisher)

| Relationship | Referencing table | Referencing attribute |
| --- | --- | --- |
| publisher_appmodule | `appmodule` | `publisherid` |
| Publisher_DuplicateBaseRecord | `duplicaterecord` | `baserecordid` |
| Publisher_DuplicateMatchingRecord | `duplicaterecord` | `duplicaterecordid` |
| Publisher_PublisherAddress | `publisheraddress` | `parentid` |
| **publisher_solution** | `solution` | `publisherid` |
| Publisher_SyncErrors | `syncerror` | `regardingobjectid` |

No many-to-many relationships are defined on `publisher`.

## Relevance to PCF2BPF

`publisher` isn't queried anywhere in `lib/dataverse.ts` — this tool never resolves a BPF's or PCF control's
publisher directly. It's documented here because `customizationprefix` is the source of the prefixes visible
throughout PCF2BPF's own UI: entity/attribute logical names like `msdyn_iotalert` or `msdyn_customerasset`
(shown next to field names in `StagesFields`/`FieldPropertiesPanel`, and in BPF `uniquename`/`primaryentity`
values) get their `msdyn_`/`new_`/custom prefix from whichever publisher owns the [solution](./solution.md)
that introduced them — `solution.publisherid` → `publisher.customizationprefix`. Understanding that chain is
useful context when a field or BPF's logical name looks unfamiliar, even though this tool has no reason to
query `publisher` itself: nothing it does (loading BPFs/PCF controls, editing form XML, publishing) needs to
know who owns the underlying solution, only the already-resolved logical names Dataverse returns.
