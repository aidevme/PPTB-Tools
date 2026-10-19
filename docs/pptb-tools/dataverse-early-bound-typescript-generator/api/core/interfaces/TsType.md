# Interface: TsType

Defined in: [core/types.ts:191](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L191)

Mirrors `TypeScriptType` in dataverse-gen.

## Properties

### definitelyTypedAttributeType?

> `optional` **definitelyTypedAttributeType?**: `string`

Defined in: [core/types.ts:197](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L197)

`Xrm.Attributes.*Attribute` for the form-context template; `undefined` when unknown.

***

### definitelyTypedControlType?

> `optional` **definitelyTypedControlType?**: `string`

Defined in: [core/types.ts:199](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L199)

`Xrm.Controls.*Control` for the form-context template; `undefined` when unknown.

***

### importLocation?

> `optional` **importLocation?**: `string`

Defined in: [core/types.ts:195](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L195)

Module specifier for an `import("...")` type reference, or `undefined` for built-ins.

***

### name

> **name**: `string`

Defined in: [core/types.ts:192](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L192)

***

### outputType

> **outputType**: [`OutputTypeKind`](../type-aliases/OutputTypeKind.md)

Defined in: [core/types.ts:193](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/types.ts#L193)
