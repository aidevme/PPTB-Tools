# Interface: GenerationResult

Defined in: [config/index.ts:210](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L210)

What a Generate run produced, for [recordGeneration](../functions/recordGeneration.md).

## Properties

### files

> **files**: `string`[]

Defined in: [config/index.ts:212](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L212)

Relative paths of every file this run generated (written or already up to date).

***

### newFiles

> **newFiles**: `string`[]

Defined in: [config/index.ts:214](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L214)

Relative paths this run created on disk. Used instead of the previous list on a project's first run.
