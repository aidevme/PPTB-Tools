# Function: useConnection()

> **useConnection**(): `object`

Defined in: [hooks/useConnection.ts:7](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/hooks/useConnection.ts#L7)

Tracks the active PPTB Dataverse connection. Reads it once on mount and again whenever PPTB raises a
`connection:*` event; in standalone dev mode (no `window.toolboxAPI`) it resolves to `null`.

## Returns

`object`

### connection

> **connection**: `Connection` \| `null`

### isLoading

> **isLoading**: `boolean`

### refreshConnection

> **refreshConnection**: () => `Promise`\<`void`\>

#### Returns

`Promise`\<`void`\>
