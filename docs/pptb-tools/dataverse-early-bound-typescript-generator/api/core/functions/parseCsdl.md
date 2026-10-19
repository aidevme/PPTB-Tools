# Function: parseCsdl()

> **parseCsdl**(`xml`, `parser?`): [`EdmxSchema`](../interfaces/EdmxSchema.md)

Defined in: [core/csdl.ts:99](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/csdl.ts#L99)

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
