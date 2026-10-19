# Class: PptbFileSink

Defined in: [services/fileSink.ts:65](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L65)

`toolboxAPI.fileSystem` adapter.

## Remarks

Every method throws when the PPTB file system API isn't available (outside Power Platform ToolBox).
`list` and `read` check `exists` first, so a missing directory lists as `[]` and a missing file reads as `null`.

## Implements

- [`FileSink`](../interfaces/FileSink.md)

## Constructors

### Constructor

> **new PptbFileSink**(): `PptbFileSink`

#### Returns

`PptbFileSink`

## Methods

### createDirectory()

> **createDirectory**(`path`): `Promise`\<`void`\>

Defined in: [services/fileSink.ts:89](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L89)

Create a directory and any missing parents.

#### Parameters

##### path

`string`

#### Returns

`Promise`\<`void`\>

#### Implementation of

[`FileSink`](../interfaces/FileSink.md).[`createDirectory`](../interfaces/FileSink.md#createdirectory)

***

### deleteFiles()

> **deleteFiles**(`paths`): `Promise`\<`string`[]\>

Defined in: [services/fileSink.ts:98](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L98)

PPTB's file system API has no delete, so this runs the commands from [buildDeleteCommands](../functions/buildDeleteCommands.md) in a hidden
PPTB terminal (PowerShell on Windows), closes it, and then checks which files still exist. The check, not
the terminal's output, decides what was deleted.

#### Parameters

##### paths

`string`[]

#### Returns

`Promise`\<`string`[]\>

#### Implementation of

[`FileSink`](../interfaces/FileSink.md).[`deleteFiles`](../interfaces/FileSink.md#deletefiles)

***

### exists()

> **exists**(`path`): `Promise`\<`boolean`\>

Defined in: [services/fileSink.ts:71](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L71)

Resolves to `true` when a file or directory exists at `path`.

#### Parameters

##### path

`string`

#### Returns

`Promise`\<`boolean`\>

#### Implementation of

[`FileSink`](../interfaces/FileSink.md).[`exists`](../interfaces/FileSink.md#exists)

***

### list()

> **list**(`dir`): `Promise`\<[`DirectoryEntry`](../interfaces/DirectoryEntry.md)[]\>

Defined in: [services/fileSink.ts:75](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L75)

Directory listing; resolves to `[]` when the directory does not exist.

#### Parameters

##### dir

`string`

#### Returns

`Promise`\<[`DirectoryEntry`](../interfaces/DirectoryEntry.md)[]\>

#### Implementation of

[`FileSink`](../interfaces/FileSink.md).[`list`](../interfaces/FileSink.md#list)

***

### read()

> **read**(`path`): `Promise`\<`string` \| `null`\>

Defined in: [services/fileSink.ts:80](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L80)

File contents, or `null` when the file does not exist.

#### Parameters

##### path

`string`

#### Returns

`Promise`\<`string` \| `null`\>

#### Implementation of

[`FileSink`](../interfaces/FileSink.md).[`read`](../interfaces/FileSink.md#read)

***

### write()

> **write**(`path`, `content`): `Promise`\<`void`\>

Defined in: [services/fileSink.ts:85](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L85)

Writes `content` to the file, replacing it if it exists. Callers create the parent directory first
([FileSink.createDirectory](../interfaces/FileSink.md#createdirectory)), as [applyWritePlan](../functions/applyWritePlan.md) does.

#### Parameters

##### path

`string`

##### content

`string`

#### Returns

`Promise`\<`void`\>

#### Implementation of

[`FileSink`](../interfaces/FileSink.md).[`write`](../interfaces/FileSink.md#write)
