# Interface: SettingsPanelProps

Defined in: [components/panels/SettingsPanel.tsx:113](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L113)

Props for [SettingsPanel](../functions/SettingsPanel.md).

## Properties

### onOpenChange

> **onOpenChange**: (`open`) => `void`

Defined in: [components/panels/SettingsPanel.tsx:120](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L120)

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

Defined in: [components/panels/SettingsPanel.tsx:127](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L127)

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

Defined in: [components/panels/SettingsPanel.tsx:115](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L115)

Whether the drawer is open. Each time it opens, the draft starts again from `settings` and the search is cleared.

***

### settings

> **settings**: [`ToolConfig`](../../config/interfaces/ToolConfig.md)

Defined in: [components/panels/SettingsPanel.tsx:122](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L122)

The saved settings; edits are kept in a draft until Save.
