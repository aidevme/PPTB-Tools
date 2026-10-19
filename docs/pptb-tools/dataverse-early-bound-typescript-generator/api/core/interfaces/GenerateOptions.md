# Interface: GenerateOptions

Defined in: [core/generator.ts:52](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/generator.ts#L52)

Choices about the generated output that aren't part of `.dataverse-gen.json`.

## Properties

### renameDuplicateIdentifiers?

> `optional` **renameDuplicateIdentifiers?**: `boolean`

Defined in: [core/generator.ts:57](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/generator.ts#L57)

Rename later duplicate enum members (see [renameDuplicateEnumMembers](../functions/renameDuplicateEnumMembers.md)) instead of writing them as
dataverse-gen does, which TypeScript rejects.
