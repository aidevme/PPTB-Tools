# Interface: PlannedFile

Defined in: [types/WritePlan.ts:14](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L14)

One file in a [WritePlan](WritePlan.md): a generated file to create, overwrite or leave alone, or an orphan.

## Properties

### absolutePath

> **absolutePath**: `string`

Defined in: [types/WritePlan.ts:18](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L18)

Absolute host path that will be written (or, for orphans, that exists).

***

### content?

> `optional` **content?**: `string`

Defined in: [types/WritePlan.ts:22](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L22)

New content; `undefined` for orphans.

***

### duplicateIdentifiers?

> `optional` **duplicateIdentifiers?**: [`DuplicateIdentifier`](../../core/interfaces/DuplicateIdentifier.md)[]

Defined in: [types/WritePlan.ts:30](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L30)

For `duplicate` files: the names declared more than once.

***

### existingContent?

> `optional` **existingContent?**: `string` \| `null`

Defined in: [types/WritePlan.ts:24](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L24)

Current on-disk content; `null` for new files, `undefined` when not read (orphans).

***

### generatedName?

> `optional` **generatedName?**: `string`

Defined in: [types/WritePlan.ts:26](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L26)

Set when an existing file with different casing is reused for the generated name.

***

### inProjectFolder?

> `optional` **inProjectFolder?**: `boolean`

Defined in: [types/WritePlan.ts:35](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L35)

Set for files outside the output folder: dataverse-gen's templates, written under the config's `templateRoot`.
`relativePath` is then relative to the project folder.

***

### relativePath

> **relativePath**: `string`

Defined in: [types/WritePlan.ts:16](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L16)

Path relative to the output root, forward slashes, using the on-disk name when one exists.

***

### status

> **status**: [`FileStatus`](../type-aliases/FileStatus.md)

Defined in: [types/WritePlan.ts:20](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L20)

How the file compares with disk; Generate acts on `writeStatus` for `duplicate` files.

***

### writeStatus?

> `optional` **writeStatus?**: [`WriteStatus`](../type-aliases/WriteStatus.md)

Defined in: [types/WritePlan.ts:28](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L28)

For `duplicate` files: whether Generate creates, overwrites or skips the file. Generate still writes it.
