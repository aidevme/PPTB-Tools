# Function: mapWithConcurrency()

> **mapWithConcurrency**\<`T`, `R`\>(`items`, `limit`, `fn`, `onProgress?`): `Promise`\<`R`[]\>

Defined in: [services/concurrency.ts:5](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/concurrency.ts#L5)

Run `fn` over `items` with at most `limit` in flight at once, preserving result order. Used to keep
the number of parallel Dataverse metadata requests small (the guide recommends 4 to 6).

## Type Parameters

### T

`T`

### R

`R`

## Parameters

### items

readonly `T`[]

### limit

`number`

### fn

(`item`, `index`) => `Promise`\<`R`\>

### onProgress?

(`completed`, `total`, `item`) => `void`

## Returns

`Promise`\<`R`[]\>
