# Function: saveProjectConfig()

> **saveProjectConfig**(`sink`, `projectRoot`, `config`): `Promise`\<`string`\>

Defined in: [services/projectConfig.ts:35](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/projectConfig.ts#L35)

Writes the config to the project's `.dataverse-gen.json`, replacing the file.

## Parameters

### sink

[`FileSink`](../interfaces/FileSink.md)

### projectRoot

`string`

### config

[`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)

## Returns

`Promise`\<`string`\>

The absolute path written.
