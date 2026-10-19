# Interface: EntitySummary

Defined in: [types/EntitySummary.ts:8](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/EntitySummary.ts#L8)

A Dataverse table as listed in the Select step.

## Properties

### description

> **description**: `string`

Defined in: [types/EntitySummary.ts:16](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/EntitySummary.ts#L16)

The table's description in the user's language; empty when it has none.

***

### displayName

> **displayName**: `string`

Defined in: [types/EntitySummary.ts:14](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/EntitySummary.ts#L14)

The table's display name in the user's language; the logical name when it has none.

***

### entitySetName?

> `optional` **entitySetName?**: `string`

Defined in: [types/EntitySummary.ts:18](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/EntitySummary.ts#L18)

The Web API collection name, for example `accounts`; `undefined` when the metadata doesn't include one.

***

### isCustom

> **isCustom**: `boolean`

Defined in: [types/EntitySummary.ts:22](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/EntitySummary.ts#L22)

Created by a customizer rather than shipped with Dataverse.

***

### isManaged

> **isManaged**: `boolean`

Defined in: [types/EntitySummary.ts:24](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/EntitySummary.ts#L24)

Part of a managed solution.

***

### logicalName

> **logicalName**: `string`

Defined in: [types/EntitySummary.ts:10](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/EntitySummary.ts#L10)

The table's logical name, for example `account`; the name a project's config lists.

***

### metadataId

> **metadataId**: `string`

Defined in: [types/EntitySummary.ts:20](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/EntitySummary.ts#L20)

`MetadataId`, used to match `solutioncomponent` rows for the solution filter.

***

### schemaName

> **schemaName**: `string`

Defined in: [types/EntitySummary.ts:12](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/EntitySummary.ts#L12)

The table's schema name, for example `Account`; the logical name when Dataverse returns none.

***

### tableType

> **tableType**: [`TableType`](../type-aliases/TableType.md)

Defined in: [types/EntitySummary.ts:26](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/EntitySummary.ts#L26)

The kind of table, as Power Apps shows it.
