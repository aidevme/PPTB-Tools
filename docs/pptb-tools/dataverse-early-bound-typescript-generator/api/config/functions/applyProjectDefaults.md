# Function: applyProjectDefaults()

> **applyProjectDefaults**(`config`, `projectDefaults`): [`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)

Defined in: [config/index.ts:203](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L203)

A new project's `.dataverse-gen.json` with the project defaults applied. Everything else in `config`
(selection, other output options) is kept.

## Parameters

### config

[`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)

The project's `.dataverse-gen.json` content.

### projectDefaults

[`ProjectDefaults`](../interfaces/ProjectDefaults.md)

The Settings panel's Options.

## Returns

[`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)

The config with the defaults applied.

## Remarks

The custom enum template is the exception: its default is only filled in when the project has no value,
so a project keeps its own choice when it's opened again or the default changes (spec 001, Amendment 2).
