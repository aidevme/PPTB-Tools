# Interface: OperationSummary

Defined in: [types/OperationSummary.ts:2](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/OperationSummary.ts#L2)

An OData action or function, as listed in the Select step.

## Properties

### boundTo?

> `optional` **boundTo?**: `string`

Defined in: [types/OperationSummary.ts:10](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/OperationSummary.ts#L10)

Logical name of the entity a bound operation binds to (first parameter's type), if any.

***

### componentId?

> `optional` **componentId?**: `string`

Defined in: [types/OperationSummary.ts:26](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/OperationSummary.ts#L26)

Id of the solution-aware record behind the operation (`customapiid` or `workflowid`), used for the
solution filter. Built-in messages have none and never match a solution.

***

### displayName?

> `optional` **displayName?**: `string`

Defined in: [types/OperationSummary.ts:21](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/OperationSummary.ts#L21)

Custom API / process action display name, when it has one.

***

### inMetadata

> **inMetadata**: `boolean`

Defined in: [types/OperationSummary.ts:34](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/OperationSummary.ts#L34)

`false` when the operation is not in the `$metadata` document (private custom APIs, or ones the
environment's metadata cache does not include yet). Types are then built from the `customapi`
record and its request parameters.

***

### isBound

> **isBound**: `boolean`

Defined in: [types/OperationSummary.ts:8](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/OperationSummary.ts#L8)

Bound to a table (called on a record or collection) rather than unbound.

***

### isCustomApi

> **isCustomApi**: `boolean`

Defined in: [types/OperationSummary.ts:17](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/OperationSummary.ts#L17)

Backed by a `customapi` record in the environment.

***

### isPrivate

> **isPrivate**: `boolean`

Defined in: [types/OperationSummary.ts:28](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/OperationSummary.ts#L28)

Custom API marked private (`IsPrivate = Yes`); still callable through the Web API.

***

### isProcessAction

> **isProcessAction**: `boolean`

Defined in: [types/OperationSummary.ts:19](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/OperationSummary.ts#L19)

Backed by a classic custom process action (`workflow` with category 3).

***

### kind

> **kind**: `"function"` \| `"action"`

Defined in: [types/OperationSummary.ts:6](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/OperationSummary.ts#L6)

Whether it's an OData action (changes data) or a function (reads data).

***

### name

> **name**: `string`

Defined in: [types/OperationSummary.ts:4](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/OperationSummary.ts#L4)

The message name, for example `WinOpportunity`; the name a project's config lists.

***

### parameterCount

> **parameterCount**: `number`

Defined in: [types/OperationSummary.ts:15](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/OperationSummary.ts#L15)

The parameters in `$metadata`, including a bound operation's binding parameter; `0` when the operation isn't
in `$metadata` (see [OperationSummary.inMetadata](#inmetadata)).
