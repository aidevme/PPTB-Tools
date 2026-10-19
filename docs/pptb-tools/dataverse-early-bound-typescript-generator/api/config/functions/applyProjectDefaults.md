# Function: applyProjectDefaults()

> **applyProjectDefaults**(`config`, `projectDefaults`): [`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)

Defined in: [config/index.ts:195](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L195)

A new project's `.dataverse-gen.json` with the project defaults applied. Everything else in `config`
(selection, other output options) is kept.

## Parameters

### config

[`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)

### projectDefaults

[`ProjectDefaults`](../interfaces/ProjectDefaults.md)

## Returns

[`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)
