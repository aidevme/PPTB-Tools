# Interface: AttributeMetadataInput

Defined in: [core/types.ts:129](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L129)

One attribute as returned by `EntityDefinitions(LogicalName='x')/Attributes` (plus `OptionSet` for
choice-type attributes). The same shape is produced by `RetrieveMetadataChanges`, which is what
`dataverse-gen` reads, so its test fixtures can be fed straight into this generator.

## Properties

### AttributeOf?

> `optional` **AttributeOf?**: `string` \| `null`

Defined in: [core/types.ts:138](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L138)

***

### AttributeType?

> `optional` **AttributeType?**: `string`

Defined in: [core/types.ts:132](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L132)

***

### AttributeTypeName?

> `optional` **AttributeTypeName?**: \{ `Value`: `string`; \} \| `null`

Defined in: [core/types.ts:133](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L133)

***

### DateTimeBehavior?

> `optional` **DateTimeBehavior?**: \{ `Value`: `string`; \} \| `null`

Defined in: [core/types.ts:143](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L143)

***

### Description?

> `optional` **Description?**: [`LabelInput`](LabelInput.md) \| `null`

Defined in: [core/types.ts:141](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L141)

***

### DisplayName?

> `optional` **DisplayName?**: [`LabelInput`](LabelInput.md) \| `null`

Defined in: [core/types.ts:142](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L142)

***

### Format?

> `optional` **Format?**: `string` \| `null`

Defined in: [core/types.ts:144](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L144)

***

### IsLogical?

> `optional` **IsLogical?**: `boolean`

Defined in: [core/types.ts:137](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L137)

***

### LogicalName

> **LogicalName**: `string`

Defined in: [core/types.ts:130](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L130)

***

### OptionSet?

> `optional` **OptionSet?**: [`OptionSetInput`](OptionSetInput.md) \| `null`

Defined in: [core/types.ts:145](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L145)

***

### RequiredLevel?

> `optional` **RequiredLevel?**: \{ `Value`: `string`; \} \| `null`

Defined in: [core/types.ts:134](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L134)

***

### SchemaName

> **SchemaName**: `string`

Defined in: [core/types.ts:131](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L131)

***

### SourceType?

> `optional` **SourceType?**: `number` \| `null`

Defined in: [core/types.ts:136](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L136)

0 = simple, 1 = calculated, 2 = rollup; `null` for lookups and virtual attributes.

***

### Targets?

> `optional` **Targets?**: `string`[]

Defined in: [core/types.ts:140](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L140)

Lookup / Customer / Owner targets.
