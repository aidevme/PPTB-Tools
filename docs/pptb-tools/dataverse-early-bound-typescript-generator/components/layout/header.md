# Header

The bar across the top of the tool: the app icon, title, version and subtitle on the left, and the active
connection and the **Settings** button on the right.

Source: [`src/components/layout/Header.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/layout/Header.tsx)

## Props (`HeaderProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `connection` | `ToolBoxAPI.Connection \| null` | Active PPTB connection, or `null` when there's none. |
| `onOpenSettings` | `() => void` | Opens the [SettingsPanel](../panels/settings-panel.md). |

## Behavior

- **Always visible:** `App.tsx` wraps the header in a sticky container (`stickyHeader` in `App.styles.ts`), so it
  stays at the top while the page scrolls. `useStickyBarHeights` publishes its height as `--app-header-height`,
  which `index.css` uses as `scroll-padding-top`, so jumping to a step card stops below the header.
- **Background:** a soft gradient from the brand color into the page background, with a light shadow
  underneath.
- **App icon:** a rounded tile with a code icon, filled with a brand-to-teal gradient.
- **Version:** a small badge after the title with the tool's version, read from `package.json` at build
  time. Only the version number ends up in the bundle.
- **Connection pill:**
  - **Connected:** a green status dot, "CONNECTED" and the connection name. Hovering shows the environment
    URL in a tooltip.
  - **Not connected:** an amber pill with "Not connected".
  - It has `role="status"`, so screen readers announce changes.
- **Settings** is an icon button with a tooltip. It's always enabled, even without a connection.

There's no Regenerate button any more. Use **Preview** and then **Generate** on the
[PreviewCard](../cards/preview-card.md).

Styles are in `src/styles/Header.styles.ts`. All colors come from Fluent theme tokens, so the header follows
PPTB's light and dark themes.
