# Function: createWritePlan()

> **createWritePlan**(`sink`, `projectRoot`, `config`, `generated`, `projectFiles?`): `Promise`\<[`WritePlan`](../../types/interfaces/WritePlan.md)\>

Defined in: [services/plan.ts:126](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/plan.ts#L126)

Compares the generated files (paths relative to the output folder) and `projectFiles` (paths relative to the project
folder: dataverse-gen's templates) with what's on disk, and finds the orphans in the output folders.

## Parameters

### sink

[`FileSink`](../interfaces/FileSink.md)

### projectRoot

`string`

### config

[`ResolvedConfig`](../../core/interfaces/ResolvedConfig.md)

### generated

[`GeneratedFile`](../../core/interfaces/GeneratedFile.md)[]

### projectFiles?

[`GeneratedFile`](../../core/interfaces/GeneratedFile.md)[] = `[]`

## Returns

`Promise`\<[`WritePlan`](../../types/interfaces/WritePlan.md)\>
