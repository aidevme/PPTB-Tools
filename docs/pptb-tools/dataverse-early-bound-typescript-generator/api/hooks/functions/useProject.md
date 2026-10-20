# Function: useProject()

> **useProject**(`__namedParameters`): `object`

Defined in: [hooks/useProject.ts:30](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useProject.ts#L30)

The project folder and its `.dataverse-gen.json`: opening a folder or a saved project, the folder remembered per
connection, and edits to the config (selection and Options).

## Parameters

### \_\_namedParameters

[`UseProjectOptions`](../interfaces/UseProjectOptions.md)

## Returns

### clear

> **clear**: (`kind`) => `void`

#### Parameters

##### kind

[`SelectionKind`](../../components/type-aliases/SelectionKind.md)

#### Returns

`void`

### clearAll

> **clearAll**: () => `void`

#### Returns

`void`

### config

> **config**: [`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)

### configState

> **configState**: [`ProjectConfigState`](../../services/interfaces/ProjectConfigState.md)

### loadProject

> **loadProject**: (`folder`) => `Promise`\<`void`\>

#### Parameters

##### folder

`string`

#### Returns

`Promise`\<`void`\>

### markConfigSaved

> **markConfigSaved**: (`path`) => `void`

After Generate saved `.dataverse-gen.json` at `path`.

#### Parameters

##### path

`string`

#### Returns

`void`

### openProjectFolder

> **openProjectFolder**: (`folder`) => `Promise`\<[`ProjectConfigState`](../../services/interfaces/ProjectConfigState.md)\>

Opens `folder` as the project and reads its `.dataverse-gen.json`; throws when it can't be read. Returns what was loaded.

#### Parameters

##### folder

`string`

#### Returns

`Promise`\<[`ProjectConfigState`](../../services/interfaces/ProjectConfigState.md)\>

### openSavedProject

> **openSavedProject**: (`project`) => `Promise`\<`boolean`\>

Opens a project saved with the New Project dialog: its location becomes the project folder and its
`.dataverse-gen.json` is read. If PPTB hasn't granted access to that folder in this session, the folder
picker opens there for the user to confirm instead. Resolves to `false` when that picker is cancelled.

#### Parameters

##### project

[`ProjectOpenTarget`](../../components/interfaces/ProjectOpenTarget.md)

#### Returns

`Promise`\<`boolean`\>

### pickProjectLocation

> **pickProjectLocation**: (`current`) => `Promise`\<`string` \| `null`\>

Folder picker for the New Project and edit dialogs' Location; `null` when cancelled or outside PPTB.

#### Parameters

##### current

`string`

#### Returns

`Promise`\<`string` \| `null`\>

### projectRoot

> **projectRoot**: `string` \| `null`

### rememberedFolder

> **rememberedFolder**: `string` \| `null`

### toggle

> **toggle**: (`kind`, `name`, `checked`) => `void`

#### Parameters

##### kind

[`SelectionKind`](../../components/type-aliases/SelectionKind.md)

##### name

`string`

##### checked

`boolean`

#### Returns

`void`

### updateConfig

> **updateConfig**: (`update`, `options`) => `void`

Merges `update` into the project config and, unless `options.markStale` is `false` (for values that don't change
the generated files), marks the preview out of date.

#### Parameters

##### update

`Partial`\<[`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)\>

##### options?

###### markStale?

`boolean`

#### Returns

`void`
