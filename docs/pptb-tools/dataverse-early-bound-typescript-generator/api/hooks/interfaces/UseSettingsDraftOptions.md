# Interface: UseSettingsDraftOptions

Defined in: [hooks/useSettingsDraft.ts:19](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useSettingsDraft.ts#L19)

## Properties

### onOpenChange

> **onOpenChange**: (`open`) => `void`

Defined in: [hooks/useSettingsDraft.ts:26](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useSettingsDraft.ts#L26)

#### Parameters

##### open

`boolean`

#### Returns

`void`

***

### onSave

> **onSave**: (`settings`) => `Promise`\<`void`\>

Defined in: [hooks/useSettingsDraft.ts:25](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useSettingsDraft.ts#L25)

Persists the settings; rejects when saving fails.

#### Parameters

##### settings

[`ToolConfig`](../../config/interfaces/ToolConfig.md)

#### Returns

`Promise`\<`void`\>

***

### open

> **open**: `boolean`

Defined in: [hooks/useSettingsDraft.ts:21](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useSettingsDraft.ts#L21)

Whether the Settings panel is open; the draft starts from the saved settings every time it opens.

***

### settings

> **settings**: [`ToolConfig`](../../config/interfaces/ToolConfig.md)

Defined in: [hooks/useSettingsDraft.ts:23](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useSettingsDraft.ts#L23)

The saved settings.
