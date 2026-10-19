# Interface: EntityMetadataInput

Defined in: [core/types.ts:169](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L169)

Entity metadata needed by the generator, independent of how it was fetched.

## Properties

### Attributes

> **Attributes**: [`AttributeMetadataInput`](AttributeMetadataInput.md)[]

Defined in: [core/types.ts:174](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L174)

***

### EntitySetName

> **EntitySetName**: `string`

Defined in: [core/types.ts:172](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L172)

***

### LogicalName

> **LogicalName**: `string`

Defined in: [core/types.ts:170](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L170)

***

### ManyToManyRelationships?

> `optional` **ManyToManyRelationships?**: [`ManyToManyRelationshipInput`](ManyToManyRelationshipInput.md)[]

Defined in: [core/types.ts:181](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L181)

***

### ManyToOneRelationships?

> `optional` **ManyToOneRelationships?**: [`OneToManyRelationshipInput`](OneToManyRelationshipInput.md)[]

Defined in: [core/types.ts:179](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L179)

Relationships, only needed when the schema was rebuilt from metadata (`EdmxSchema.source ===
'metadata'`); a CSDL-based schema already has the navigation properties.

***

### OneToManyRelationships?

> `optional` **OneToManyRelationships?**: [`OneToManyRelationshipInput`](OneToManyRelationshipInput.md)[]

Defined in: [core/types.ts:180](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L180)

***

### PrimaryIdAttribute?

> `optional` **PrimaryIdAttribute?**: `string`

Defined in: [core/types.ts:173](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L173)

***

### SchemaName

> **SchemaName**: `string`

Defined in: [core/types.ts:171](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L171)
