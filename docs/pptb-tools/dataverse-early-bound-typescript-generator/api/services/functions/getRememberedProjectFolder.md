# Function: getRememberedProjectFolder()

> **getRememberedProjectFolder**(`key`): `Promise`\<`string` \| `undefined`\>

Defined in: [services/settings.ts:28](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/settings.ts#L28)

Returns the project folder last used with a connection, or with any connection when there's none for it.

## Parameters

### key

`string` \| `undefined`

The connection's [connectionKey](connectionKey.md); without one, only the last folder used is considered.

## Returns

`Promise`\<`string` \| `undefined`\>

The folder, or `undefined` outside PPTB, when nothing was remembered, or when reading the settings fails
(the failure is logged).
