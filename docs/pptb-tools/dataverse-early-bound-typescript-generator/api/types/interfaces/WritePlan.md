# Interface: WritePlan

Defined in: [types/WritePlan.ts:39](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L39)

What Generate would do: every generated file and orphan compared with disk, as Preview shows it.

## Properties

### counts

> **counts**: `Record`\<[`FileStatus`](../type-aliases/FileStatus.md), `number`\>

Defined in: [types/WritePlan.ts:50](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L50)

How many files have each status. To count what Generate will write, use `writeCounts` from `services/plan.ts`,
which also counts `duplicate` files.

***

### files

> **files**: [`PlannedFile`](PlannedFile.md)[]

Defined in: [types/WritePlan.ts:45](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L45)

The generated files and orphans, with their statuses.

***

### outputRoot

> **outputRoot**: `string`

Defined in: [types/WritePlan.ts:43](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L43)

Absolute path of the output folder, resolved from the config's `outputRoot`.

***

### projectRoot

> **projectRoot**: `string`

Defined in: [types/WritePlan.ts:41](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L41)

Absolute path of the project folder.
