# Function: rememberProjectFolder()

> **rememberProjectFolder**(`key`, `folder`): `Promise`\<`void`\>

Defined in: [services/settings.ts:49](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/settings.ts#L49)

Remembers `folder` for the connection and as the last folder used. Does nothing outside PPTB; a failed save is
logged, not thrown.

## Parameters

### key

`string` \| `undefined`

The connection's [connectionKey](connectionKey.md); without one, only the last folder used is updated.

### folder

`string`

## Returns

`Promise`\<`void`\>
