# Function: dataverseGenTemplateFiles()

> **dataverseGenTemplateFiles**(`config`, `options?`): [`GeneratedFile`](../../core/interfaces/GeneratedFile.md)[]

Defined in: [services/dataverseGenTemplates.ts:59](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/dataverseGenTemplates.ts#L59)

The template files to write, with paths relative to the project folder (not the output folder), under the
config's `templateRoot`: `_templates/action.ejs` and so on by default.

## Parameters

### config

[`ResolvedConfig`](../../core/interfaces/ResolvedConfig.md)

The project's resolved config; its `output.templateRoot` picks the folder.

### options?

[`TemplateFileOptions`](../interfaces/TemplateFileOptions.md) = `{}`

Whether to write the custom `enum.ejs`.

## Returns

[`GeneratedFile`](../../core/interfaces/GeneratedFile.md)[]

The seven template files, in dataverse-gen's order.
