# Function: parseCsdl()

> **parseCsdl**(`xml`, `parser?`): [`EdmxSchema`](../interfaces/EdmxSchema.md)

Defined in: [core/csdl.ts:99](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/csdl.ts#L99)

Parse a `$metadata` document into an [EdmxSchema](../interfaces/EdmxSchema.md).

Entity types, complex types, actions and functions are sorted by name (as dataverse-gen does);
enum types keep document order.

## Parameters

### xml

`string`

### parser?

[`XmlParser`](../interfaces/XmlParser.md) = `...`

## Returns

[`EdmxSchema`](../interfaces/EdmxSchema.md)
