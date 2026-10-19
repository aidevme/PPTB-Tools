# Function: recordGeneration()

> **recordGeneration**(`project`, `result`, `now`): [`ProjectEntry`](../interfaces/ProjectEntry.md) \| `undefined`

Defined in: [config/index.ts:222](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/config/index.ts#L222)

The project after a Generate run. When the run added files, or no longer produces files the previous run
did, the version gets a patch bump and `modifiedOn` becomes `now`. The file list is recorded either way.
Returns `undefined` when nothing about the project changed.

## Parameters

### project

[`ProjectEntry`](../interfaces/ProjectEntry.md)

### result

[`GenerationResult`](../interfaces/GenerationResult.md)

### now

`string`

## Returns

[`ProjectEntry`](../interfaces/ProjectEntry.md) \| `undefined`
