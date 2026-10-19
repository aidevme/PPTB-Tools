# Interface: FileSink

Defined in: [services/fileSink.ts:15](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L15)

The file operations the write planner and the project config use. Every path is absolute.

## Methods

### createDirectory()

> **createDirectory**(`path`): `Promise`\<`void`\>

Defined in: [services/fileSink.ts:28](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L28)

Create a directory and any missing parents.

#### Parameters

##### path

`string`

#### Returns

`Promise`\<`void`\>

***

### deleteFiles()

> **deleteFiles**(`paths`): `Promise`\<`string`[]\>

Defined in: [services/fileSink.ts:30](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L30)

Delete files; resolves to the paths that still exist afterwards (empty when every delete succeeded).

#### Parameters

##### paths

`string`[]

#### Returns

`Promise`\<`string`[]\>

***

### exists()

> **exists**(`path`): `Promise`\<`boolean`\>

Defined in: [services/fileSink.ts:17](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L17)

Resolves to `true` when a file or directory exists at `path`.

#### Parameters

##### path

`string`

#### Returns

`Promise`\<`boolean`\>

***

### list()

> **list**(`dir`): `Promise`\<[`DirectoryEntry`](DirectoryEntry.md)[]\>

Defined in: [services/fileSink.ts:19](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L19)

Directory listing; resolves to `[]` when the directory does not exist.

#### Parameters

##### dir

`string`

#### Returns

`Promise`\<[`DirectoryEntry`](DirectoryEntry.md)[]\>

***

### read()

> **read**(`path`): `Promise`\<`string` \| `null`\>

Defined in: [services/fileSink.ts:21](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L21)

File contents, or `null` when the file does not exist.

#### Parameters

##### path

`string`

#### Returns

`Promise`\<`string` \| `null`\>

***

### write()

> **write**(`path`, `content`): `Promise`\<`void`\>

Defined in: [services/fileSink.ts:26](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L26)

Writes `content` to the file, replacing it if it exists. Callers create the parent directory first
([FileSink.createDirectory](#createdirectory)), as [applyWritePlan](../functions/applyWritePlan.md) does.

#### Parameters

##### path

`string`

##### content

`string`

#### Returns

`Promise`\<`void`\>
