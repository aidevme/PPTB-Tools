# Interface: SettingsPanelProps

Defined in: [components/panels/SettingsPanel.tsx:120](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L120)

Props for [SettingsPanel](../functions/SettingsPanel.md).

## Properties

### editedEnumTemplatePath?

> `optional` **editedEnumTemplatePath?**: `string`

Defined in: [components/panels/SettingsPanel.tsx:140](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L140)

The project's `enum.ejs` path when the last preview found it edited (`editedEnumTemplate`). When Save turns the
custom enum template on with Generate templates on, the panel then asks before saving, since the next Generate
would overwrite the file (spec 001, FR-012). Without it, Save never asks.

***

### onOpenChange

> **onOpenChange**: (`open`) => `void`

Defined in: [components/panels/SettingsPanel.tsx:127](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L127)

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

Defined in: [components/panels/SettingsPanel.tsx:134](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L134)

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

Defined in: [components/panels/SettingsPanel.tsx:122](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L122)

Whether the drawer is open. Each time it opens, the draft starts again from `settings` and the search is cleared.

***

### settings

> **settings**: [`ToolConfig`](../../config/interfaces/ToolConfig.md)

Defined in: [components/panels/SettingsPanel.tsx:129](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L129)

The saved settings; edits are kept in a draft until Save.
