# Interface: DirectoryEntry

Defined in: [services/fileSink.ts:7](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L7)

One entry of a directory listing ([FileSink.list](FileSink.md#list)).

## Properties

### name

> **name**: `string`

Defined in: [services/fileSink.ts:9](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L9)

The entry's name inside the directory, not a path.

***

### type

> **type**: `"directory"` \| `"file"`

Defined in: [services/fileSink.ts:11](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L11)

Whether the entry is a file or a subdirectory.
