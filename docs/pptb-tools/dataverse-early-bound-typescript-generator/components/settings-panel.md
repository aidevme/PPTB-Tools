# SettingsPanel

Tool settings, shown in a Fluent UI `OverlayDrawer` that slides in from the right edge. It opens from the
Settings button in the [Header](./header.md).

Source: [`src/components/SettingsPanel.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/SettingsPanel.tsx)

## Props (`SettingsPanelProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `open` | `boolean` | Whether the drawer is shown. |
| `onOpenChange` | `(open: boolean) => void` | Called when the drawer opens or closes. |

## Behavior

- Closes from its close (X) button, the Escape key, or a click outside the drawer.
- `App.tsx` holds the open state (`settingsOpen`).
- It has no settings yet; the body shows a placeholder.
