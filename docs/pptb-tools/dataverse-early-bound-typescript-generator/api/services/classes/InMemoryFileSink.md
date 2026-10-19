# Class: InMemoryFileSink

Defined in: [services/fileSink.ts:119](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L119)

In-memory implementation for unit tests. Paths are compared case-sensitively, like a Linux disk.

## Implements

- [`FileSink`](../interfaces/FileSink.md)

## Constructors

### Constructor

> **new InMemoryFileSink**(`initialFiles?`): `InMemoryFileSink`

Defined in: [services/fileSink.ts:129](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L129)

Creates the sink with `initialFiles` already on "disk".

#### Parameters

##### initialFiles?

`Record`\<`string`, `string`\> = `{}`

File contents by absolute path; their parent directories are created too.

#### Returns

`InMemoryFileSink`

## Properties

### directories

> `readonly` **directories**: `Set`\<`string`\>

Defined in: [services/fileSink.ts:123](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L123)

Every directory that exists, by absolute path.

***

### files

> `readonly` **files**: `Map`\<`string`, `string`\>

Defined in: [services/fileSink.ts:121](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L121)

File contents by absolute path; tests read it to check what was written.

## Methods

### createDirectory()

> **createDirectory**(`path`): `Promise`\<`void`\>

Defined in: [services/fileSink.ts:176](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L176)

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

Defined in: [services/fileSink.ts:184](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L184)

Delete files; resolves to the paths that still exist afterwards (empty when every delete succeeded).

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

Defined in: [services/fileSink.ts:148](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L148)

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

Defined in: [services/fileSink.ts:152](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L152)

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

Defined in: [services/fileSink.ts:163](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L163)

File contents, or `null` when the file does not exist.

#### Parameters

##### path

`string`

#### Returns

`Promise`\<`string` \| `null`\>

#### Implementation of

[`FileSink`](../interfaces/FileSink.md).[`read`](../interfaces/FileSink.md#read)

***

### seed()

> **seed**(`path`, `content`): `void`

Defined in: [services/fileSink.ts:139](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L139)

Puts a file on "disk", creating its parent directories, without the checks [InMemoryFileSink.write](#write) makes.

#### Parameters

##### path

`string`

##### content

`string`

#### Returns

`void`

***

### write()

> **write**(`path`, `content`): `Promise`\<`void`\>

Defined in: [services/fileSink.ts:171](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L171)

Writes `content` to the file, replacing it if it exists. Callers create the parent directory first
([FileSink.createDirectory](../interfaces/FileSink.md#createdirectory)), as [applyWritePlan](../functions/applyWritePlan.md) does.

#### Parameters

##### path

`string`

##### content

`string`

#### Returns

`Promise`\<`void`\>

#### Throws

An `Error` when the parent directory doesn't exist, to catch writes the planner didn't prepare.

#### Implementation of

[`FileSink`](../interfaces/FileSink.md).[`write`](../interfaces/FileSink.md#write)
