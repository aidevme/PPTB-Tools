# Interface: EdmxOperation

Defined in: [core/types.ts:73](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L73)

An `<Action>` or `<Function>` in the CSDL.

## Properties

### IsBound

> **IsBound**: `boolean`

Defined in: [core/types.ts:75](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L75)

***

### Name

> **Name**: `string`

Defined in: [core/types.ts:74](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L74)

***

### Parameters

> **Parameters**: [`EdmxParameter`](EdmxParameter.md)[]

Defined in: [core/types.ts:79](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L79)

***

### ReturnsCollection

> **ReturnsCollection**: `boolean`

Defined in: [core/types.ts:78](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L78)

***

### ReturnType?

> `optional` **ReturnType?**: `string`

Defined in: [core/types.ts:77](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L77)

Return type without the `Collection(...)` wrapper.
