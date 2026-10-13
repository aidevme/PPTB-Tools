# SettingsPanel

Tool settings, shown in a Fluent UI `OverlayDrawer` that slides in from the right edge. It opens from the
Settings button in the [Header](./header.md).

Source: [`src/components/panels/SettingsPanel.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/panels/SettingsPanel.tsx)

## Props (`SettingsPanelProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `open` | `boolean` | Whether the drawer is shown. |
| `onOpenChange` | `(open: boolean) => void` | Called when the drawer opens or closes. |
| `settings` | `ToolConfig` | The saved settings. Edits are made on a draft copy until Save. |
| `onSave` | `(settings: ToolConfig) => Promise<void>` | Persists the settings. The panel closes when it resolves and shows the error when it rejects. |

## Behavior

- Closes from its close (X) button, the Escape key, or a click outside the drawer.
- `App.tsx` holds the open state (`settingsOpen`).
- Three vertical tabs on the left, **General**, **Options** and **Schema Generation**, switch the content on the right. The
  selected tab is view state inside the component and starts on General.
- **General** has no settings yet and shows a placeholder.
- **Options** holds the defaults for new projects: **Output folder**, **Early-bound entity interfaces
  (dataverse-ify)**, **Form context helpers (Xrm.FormContext)** and **index.ts barrel file**, each with an info
  label. They're applied when a project folder without `.dataverse-gen.json` is opened; existing projects keep
  their own values, set on the [OptionsCard](./options-card.md). A blank output folder saves as the default
  (`./src/dataverse-gen`).
- **Schema Generation** has a **Delete Orphaned Files** checkbox.
- **Save and Cancel** sit at the bottom. Each time the panel opens it starts from the saved values. **Save** is
  enabled only when a value differs from the saved one; it saves and closes the panel, or shows the error and
  stays open if saving fails. **Cancel** (or closing the panel) discards the changes.
- **Where values come from:** the defaults are in
  `src/config/dataverse-early-bound-typescript-generator-config.json` (`deleteOrphanedFiles: false`), bundled
  at build time. Saved values are stored in PPTB's per-tool settings (`toolboxAPI.settings`, key
  `toolConfig`) and applied over the defaults every time the tool loads. The tool can't write the JSON file
  itself: PPTB doesn't tell a tool where it's installed and only lets it write to folders the user picked.
- The setting isn't applied yet: PPTB's file API has no delete, so orphaned files are still only reported.
