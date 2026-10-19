# Function: withRetry()

> **withRetry**\<`T`\>(`operation`, `options?`): `Promise`\<`T`\>

Defined in: [services/errors.ts:161](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/errors.ts#L161)

Runs `operation`, retrying transient failures with growing delays (500 ms, then 1 s by default). Other errors,
and the last transient one, are rethrown unchanged.

## Type Parameters

### T

`T`

## Parameters

### operation

() => `Promise`\<`T`\>

### options?

[`RetryOptions`](../interfaces/RetryOptions.md) = `{}`

## Returns

`Promise`\<`T`\>
