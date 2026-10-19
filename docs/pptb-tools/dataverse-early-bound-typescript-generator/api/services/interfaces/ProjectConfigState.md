# Interface: ProjectConfigState

Defined in: [services/projectConfig.ts:9](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/projectConfig.ts#L9)

The project's `.dataverse-gen.json`, as [loadProjectConfig](../functions/loadProjectConfig.md) found it.

## Properties

### config

> **config**: [`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)

Defined in: [services/projectConfig.ts:15](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/projectConfig.ts#L15)

The parsed config, or the defaults a fresh `dataverse-gen init` would write when the file doesn't exist.

***

### exists

> **exists**: `boolean`

Defined in: [services/projectConfig.ts:13](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/projectConfig.ts#L13)

Whether the file exists; a new project's config is only written on the first Generate.

***

### path

> **path**: `string`

Defined in: [services/projectConfig.ts:11](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/projectConfig.ts#L11)

Absolute path of the config file (whether or not it exists yet).
