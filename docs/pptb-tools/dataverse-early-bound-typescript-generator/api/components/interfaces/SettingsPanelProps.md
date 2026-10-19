# Interface: SettingsPanelProps

Defined in: [components/panels/SettingsPanel.tsx:114](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L114)

Props for [SettingsPanel](../functions/SettingsPanel.md).

## Properties

### onOpenChange

> **onOpenChange**: (`open`) => `void`

Defined in: [components/panels/SettingsPanel.tsx:121](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L121)

Called with `false` when the panel should close: the Close or Cancel button, the drawer's own dismiss (for
example Escape), or a successful Save.

#### Parameters

##### open

`boolean`

#### Returns

`void`

***

### onSave

> **onSave**: (`settings`) => `Promise`\<`void`\>

Defined in: [components/panels/SettingsPanel.tsx:128](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L128)

Called with the draft when Save is clicked, to persist it. The panel closes when it resolves and shows the error
when it rejects.

#### Parameters

##### settings

[`ToolConfig`](../../config/interfaces/ToolConfig.md)

#### Returns

`Promise`\<`void`\>

***

### open

> **open**: `boolean`

Defined in: [components/panels/SettingsPanel.tsx:116](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L116)

Whether the drawer is open. Each time it opens, the draft starts again from `settings` and the search is cleared.

***

### settings

> **settings**: [`ToolConfig`](../../config/interfaces/ToolConfig.md)

Defined in: [components/panels/SettingsPanel.tsx:123](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L123)

The saved settings; edits are kept in a draft until Save.
