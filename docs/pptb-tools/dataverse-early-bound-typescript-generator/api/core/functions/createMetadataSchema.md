# Function: createMetadataSchema()

> **createMetadataSchema**(`entities`): [`EdmxSchema`](../interfaces/EdmxSchema.md)

Defined in: [core/metadataSchema.ts:40](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/metadataSchema.ts#L40)

An [EdmxSchema](../interfaces/EdmxSchema.md) with one entity type per table and no actions, functions, complex types or
enums. Navigation properties are left empty; `buildSchemaModel` derives them per entity with
[navigationFromRelationships](navigationFromRelationships.md).

## Parameters

### entities

readonly [`EntityTypeSource`](../interfaces/EntityTypeSource.md)[]

## Returns

[`EdmxSchema`](../interfaces/EdmxSchema.md)
