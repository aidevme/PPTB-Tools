# Function: withProjectCustomTemplates()

> **withProjectCustomTemplates**(`config`, `selection`): [`DataverseGenConfig`](../interfaces/DataverseGenConfig.md)

Defined in: [core/config.ts:210](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/config.ts#L210)

A copy of the config with the project's Custom Templates choices set; every other key, including other keys of the
tool's settings object, is kept.

## Parameters

### config

[`DataverseGenConfig`](../interfaces/DataverseGenConfig.md)

The project's `.dataverse-gen.json` content.

### selection

[`CustomTemplateSelection`](../type-aliases/CustomTemplateSelection.md)

The choices to store, one per kind.

## Returns

[`DataverseGenConfig`](../interfaces/DataverseGenConfig.md)

The updated config; `config` itself isn't changed.
