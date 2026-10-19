# Function: useEnvironmentMetadata()

> **useEnvironmentMetadata**(`__namedParameters`): `object`

Defined in: [hooks/useEnvironmentMetadata.ts:28](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/useEnvironmentMetadata.ts#L28)

The environment's lists for the Select step: tables, actions and functions (loaded on demand), solutions and the
solution filter, plus the warning shown when `$metadata` is too large and the schema comes from table metadata.

## Parameters

### \_\_namedParameters

[`UseEnvironmentMetadataOptions`](../interfaces/UseEnvironmentMetadataOptions.md)

## Returns

### changeSolution

> **changeSolution**: (`solutionId`) => `Promise`\<`void`\>

#### Parameters

##### solutionId

`string` \| `null`

#### Returns

`Promise`\<`void`\>

### ensureOperations

> **ensureOperations**: () => `void`

#### Returns

`void`

### entities

> **entities**: [`EntitySummary`](../../types/interfaces/EntitySummary.md)[]

### loadingEntities

> **loadingEntities**: `boolean`

### loadingOperations

> **loadingOperations**: `boolean`

### loadingSolution

> **loadingSolution**: `boolean`

### missing

> **missing**: `Record`\<[`SelectionKind`](../../components/type-aliases/SelectionKind.md), `string`[]\>

Selected names the environment doesn't have (once the matching list has loaded).

### noteMetadataFallback

> **noteMetadataFallback**: () => `void`

Records whether the provider fell back to building the schema from table metadata (shows the warning).

#### Returns

`void`

### operations

> **operations**: [`OperationSummary`](../../types/interfaces/OperationSummary.md)[] \| `null`

### selectedSolutionId

> **selectedSolutionId**: `string` \| `null`

### showMetadataFallbackWarning

> **showMetadataFallbackWarning**: `boolean`

### solutionComponentIds

> **solutionComponentIds**: `Set`\<`string`\> \| `null`

### solutionEntityIds

> **solutionEntityIds**: `Set`\<`string`\> \| `null`

### solutions

> **solutions**: [`SolutionSummary`](../../types/interfaces/SolutionSummary.md)[]
