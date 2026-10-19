# Function: loadProjectConfig()

> **loadProjectConfig**(`sink`, `projectRoot`): `Promise`\<[`ProjectConfigState`](../interfaces/ProjectConfigState.md)\>

Defined in: [services/projectConfig.ts:24](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/projectConfig.ts#L24)

Load the config if present, otherwise the defaults a fresh `dataverse-gen init` would write.

## Parameters

### sink

[`FileSink`](../interfaces/FileSink.md)

### projectRoot

`string`

## Returns

`Promise`\<[`ProjectConfigState`](../interfaces/ProjectConfigState.md)\>
