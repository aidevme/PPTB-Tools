# Function: navigationFromRelationships()

> **navigationFromRelationships**(`metadata`): [`EdmxNavigationProperty`](../interfaces/EdmxNavigationProperty.md)[]

Defined in: [core/metadataSchema.ts:73](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/metadataSchema.ts#L73)

The navigation properties the CSDL would declare on `metadata`'s entity type, rebuilt from its
relationship metadata. Sorted by name like the CSDL parser's output; duplicates are dropped.

## Parameters

### metadata

[`EntityMetadataInput`](../interfaces/EntityMetadataInput.md)

## Returns

[`EdmxNavigationProperty`](../interfaces/EdmxNavigationProperty.md)[]
