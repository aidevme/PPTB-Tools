# ConnectionStatus

The connection pill in the [Header](./header.md): which Dataverse environment the tool is connected to through
PPTB.

Source: [`src/components/layout/ConnectionStatus.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/layout/ConnectionStatus.tsx)

## Props (`IConnectionStatusProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `connection` | `ToolBoxAPI.Connection \| null` | Active PPTB connection, or `null` when there's none. |

## Behavior

- **Connected:** a green status dot, "CONNECTED" and the connection name, with the environment URL in a tooltip on
  hover. Screen readers hear "Connected to *name*".
- **Not connected:** an amber pill with "Not connected".
- The pill has `role="status"`, so screen readers announce changes.
- Long connection names are cut with an ellipsis; the pill is at most 320 px wide.

Styles: `useConnectionStatusStyles` in `src/styles/ConnectionStatus.styles.ts`, all from Fluent theme tokens.
