# Interface: UseEnvironmentMetadataOptions

Defined in: [hooks/useEnvironmentMetadata.ts:9](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useEnvironmentMetadata.ts#L9)

## Properties

### clearPlan

> **clearPlan**: () => `void`

Defined in: [hooks/useEnvironmentMetadata.ts:21](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useEnvironmentMetadata.ts#L21)

Drops the write plan when the environment's lists reload. Must be stable.

#### Returns

`void`

***

### connection

> **connection**: `Connection` \| `null`

Defined in: [hooks/useEnvironmentMetadata.ts:13](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useEnvironmentMetadata.ts#L13)

***

### hasProject

> **hasProject**: `boolean`

Defined in: [hooks/useEnvironmentMetadata.ts:15](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useEnvironmentMetadata.ts#L15)

Tables, solutions and the selection are only listed once a project is open (created or loaded).

***

### inPptb

> **inPptb**: `boolean`

Defined in: [hooks/useEnvironmentMetadata.ts:12](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useEnvironmentMetadata.ts#L12)

***

### provider

> **provider**: [`PptbMetadataProvider`](../../services/classes/PptbMetadataProvider.md)

Defined in: [hooks/useEnvironmentMetadata.ts:11](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useEnvironmentMetadata.ts#L11)

The connection's metadata provider; a new one per connection.

***

### selected

> **selected**: `Record`\<[`SelectionKind`](../../components/type-aliases/SelectionKind.md), `string`[]\>

Defined in: [hooks/useEnvironmentMetadata.ts:17](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useEnvironmentMetadata.ts#L17)

The project's selection, to tell which selected names the environment doesn't have.

***

### setError

> **setError**: (`message`) => `void`

Defined in: [hooks/useEnvironmentMetadata.ts:19](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useEnvironmentMetadata.ts#L19)

Shows an error in the page (the error bar), or clears it with `null`. Must be stable (a state setter): effects depend on it.

#### Parameters

##### message

`string` \| `null`

#### Returns

`void`
