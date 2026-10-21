# Interface: SettingsPanelProps

Defined in: [components/panels/SettingsPanel.tsx:50](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L50)

Props for [SettingsPanel](../functions/SettingsPanel.md).

## Properties

### onCopyText?

> `optional` **onCopyText?**: (`text`, `label`) => `void`

Defined in: [components/panels/SettingsPanel.tsx:69](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L69)

Copies text to the clipboard; `label` names it in the confirmation. The Advanced tab's Copy button uses it to
copy the stored settings' JSON; without it, there's no Copy button.

#### Parameters

##### text

`string`

##### label

`string`

#### Returns

`void`

***

### onOpenChange

> **onOpenChange**: (`open`) => `void`

Defined in: [components/panels/SettingsPanel.tsx:57](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L57)

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

Defined in: [components/panels/SettingsPanel.tsx:64](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L64)

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

Defined in: [components/panels/SettingsPanel.tsx:52](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L52)

Whether the drawer is open. Each time it opens, the draft starts again from `settings` and the search is cleared.

***

### settings

> **settings**: [`ToolConfig`](../../config/interfaces/ToolConfig.md)

Defined in: [components/panels/SettingsPanel.tsx:59](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L59)

The saved settings; edits are kept in a draft until Save.
