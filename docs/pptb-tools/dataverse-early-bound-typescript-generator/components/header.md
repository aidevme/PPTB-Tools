# Header

The bar across the top of the tool: title and subtitle, the active connection, the **Regenerate** button and
the **Settings** button.

Source: [`src/components/Header.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/Header.tsx)

## Props (`HeaderProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `connection` | `ToolBoxAPI.Connection \| null` | Active PPTB connection. Shown as a badge with the environment URL in a tooltip; `null` shows "No connection". |
| `canRegenerate` | `boolean` | Whether a project with a selection is loaded, so one-click regeneration can run. |
| `busy` | `boolean` | Disables Regenerate while another operation runs. |
| `onRegenerate` | `() => void` | Loads metadata, generates and writes all files for the current `.dataverse-gen.json` in one step. |
| `onOpenSettings` | `() => void` | Opens the [SettingsPanel](./settings-panel.md). |

## Behavior

- Regenerate is disabled unless `canRegenerate` is true and the tool isn't busy.
- The Settings button is always enabled, even without a connection.
- Both buttons have tooltips with an arrow.
