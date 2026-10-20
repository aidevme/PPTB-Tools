# Function: projectCustomTemplates()

> **projectCustomTemplates**(`config`): [`CustomTemplateSelection`](../type-aliases/CustomTemplateSelection.md)

Defined in: [core/config.ts:196](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/config.ts#L196)

The project's Custom Templates choices.

## Parameters

### config

[`DataverseGenConfig`](../interfaces/DataverseGenConfig.md)

The project's `.dataverse-gen.json` content.

## Returns

[`CustomTemplateSelection`](../type-aliases/CustomTemplateSelection.md)

Every kind, `true` only where the file sets it to `true`; a missing or non-boolean value is `false`.

## Remarks

Only stored for now: nothing reads them when generating.
