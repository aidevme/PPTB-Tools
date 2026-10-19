# Interface: EdmxNavigationProperty

Defined in: [core/types.ts:22](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L22)

A `<NavigationProperty>` in the CSDL.

## Properties

### FullName

> **FullName**: `string`

Defined in: [core/types.ts:26](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L26)

Name as declared in the CSDL.

***

### IsCollection

> **IsCollection**: `boolean`

Defined in: [core/types.ts:29](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L29)

***

### LogicalName

> **LogicalName**: `string`

Defined in: [core/types.ts:31](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L31)

Logical name of the target entity (last segment of [EdmxNavigationProperty.Type](#type)).

***

### Name

> **Name**: `string`

Defined in: [core/types.ts:24](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L24)

Name used in generated code (last segment of [EdmxNavigationProperty.FullName](#fullname)).

***

### Type

> **Type**: `string`

Defined in: [core/types.ts:28](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L28)

Target type without the `Collection(...)` wrapper, e.g. `mscrm.systemuser`.
