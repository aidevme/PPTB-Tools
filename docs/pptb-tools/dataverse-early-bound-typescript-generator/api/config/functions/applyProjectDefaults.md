# Function: applyProjectDefaults()

> **applyProjectDefaults**(`config`, `projectDefaults`): [`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)

Defined in: [config/index.ts:188](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L188)

A new project's `.dataverse-gen.json` with the project defaults applied. Everything else in `config`
(selection, other output options) is kept.

## Parameters

### config

[`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)

### projectDefaults

[`ProjectDefaults`](../interfaces/ProjectDefaults.md)

## Returns

[`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)
