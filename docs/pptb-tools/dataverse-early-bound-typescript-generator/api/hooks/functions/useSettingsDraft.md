# Function: useSettingsDraft()

> **useSettingsDraft**(`__namedParameters`): `object`

Defined in: [hooks/useSettingsDraft.ts:33](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useSettingsDraft.ts#L33)

The Settings panel's draft: edits are made on a copy of the saved settings, which is reset to them every time
the panel opens and only persisted by `save` (which closes the panel, or keeps it open with `saveError`).

## Parameters

### \_\_namedParameters

[`UseSettingsDraftOptions`](../interfaces/UseSettingsDraftOptions.md)

## Returns

### atDefaults

> **atDefaults**: `boolean`

### dirty

> **dirty**: `boolean`

### draft

> **draft**: [`ToolConfig`](../../config/interfaces/ToolConfig.md)

### resetToDefaults

> **resetToDefaults**: () => `void`

Reset to defaults: the bundled defaults, keeping the saved projects.

#### Returns

`void`

### save

> **save**: () => `Promise`\<`void` \| `undefined`\>

#### Returns

`Promise`\<`void` \| `undefined`\>

### saveError

> **saveError**: `string` \| `null`

### saving

> **saving**: `boolean`

### update

> **update**: (`change`) => `void`

#### Parameters

##### change

`Partial`\<[`ToolConfig`](../../config/interfaces/ToolConfig.md)\>

#### Returns

`void`

### updateGeneral

> **updateGeneral**: (`change`) => `void`

#### Parameters

##### change

`Partial`\<[`GeneralSettings`](../../config/interfaces/GeneralSettings.md)\>

#### Returns

`void`

### updateProjectDefaults

> **updateProjectDefaults**: (`change`) => `void`

#### Parameters

##### change

`Partial`\<[`ProjectDefaults`](../../config/interfaces/ProjectDefaults.md)\>

#### Returns

`void`
