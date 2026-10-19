# Function: SettingsPanel()

> **SettingsPanel**(`__namedParameters`): `Element`

Defined in: [components/panels/SettingsPanel.tsx:138](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx#L138)

Tool settings, in an overlay drawer that slides in from the right. A navigation column (search, then vertical
tabs with subtitles) sits beside section cards; each setting is a row with its title and description on the left
and its control on the right. Changes are made on a draft: a dot marks each changed value, the footer says when
there are unsaved changes, Save (enabled once something changed) persists them, and the Cancel split button
discards them; its menu also has Reset to defaults, which restores the bundled defaults (saved projects are kept).

## Parameters

### \_\_namedParameters

[`SettingsPanelProps`](../interfaces/SettingsPanelProps.md)

## Returns

`Element`
