# Interface: EdmxSchema

Defined in: [core/types.ts:83](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L83)

Parsed `$metadata` document, limited to what the generator needs.

## Properties

### actions

> **actions**: [`EdmxOperation`](EdmxOperation.md)[]

Defined in: [core/types.ts:94](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L94)

***

### complexTypes

> **complexTypes**: [`EdmxComplexType`](EdmxComplexType.md)[]

Defined in: [core/types.ts:92](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L92)

***

### entityTypes

> **entityTypes**: [`EdmxEntityType`](EdmxEntityType.md)[]

Defined in: [core/types.ts:91](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L91)

***

### enumTypes

> **enumTypes**: [`EdmxEnumType`](EdmxEnumType.md)[]

Defined in: [core/types.ts:93](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L93)

***

### functions

> **functions**: [`EdmxOperation`](EdmxOperation.md)[]

Defined in: [core/types.ts:95](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L95)

***

### source?

> `optional` **source?**: `"metadata"` \| `"csdl"`

Defined in: [core/types.ts:90](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L90)

Where the schema came from. `'metadata'` means it was rebuilt from table and relationship metadata
because the CSDL could not be loaded (see `createMetadataSchema`): entity types then carry no
navigation properties, and each entity's navigation comes from its relationship metadata instead.
Omitted for a parsed CSDL document.
