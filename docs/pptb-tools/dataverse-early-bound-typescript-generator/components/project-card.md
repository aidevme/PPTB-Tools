# ProjectCard

Step 1 of the workflow: pick the project folder and show whether it already has a `.dataverse-gen.json`.

Source: [`src/components/ProjectCard.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/ProjectCard.tsx)

## Props (`ProjectCardProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `projectRoot` | `string \| null` | The open project folder. |
| `rememberedFolder` | `string \| null` | Folder used last time with this connection. PPTB needs it re-selected through Browse before the tool can read it. |
| `configState` | `ProjectConfigState \| null` | The loaded `.dataverse-gen.json`, its path, and whether it exists. |
| `busy` | `boolean` | Disables the buttons while another operation runs. |
| `onBrowse` | `() => void` | Opens PPTB's folder picker. |
| `onReload` | `() => void` | Re-reads `.dataverse-gen.json` from disk. |
| `outputFolder` | `string \| null` | Absolute output folder (`output.outputRoot` resolved against the project). |
| `hasSelection` | `boolean` | Whether anything is selected, enabling "Clear selection". |
| `onCopyPath` | `(path: string, label: string) => void` | Copies a path to the clipboard; `label` names it in the confirmation toast. |
| `onClearSelection` | `() => void` | Clears every selected table, action and function. |

## Behavior

- **Browse…** opens the folder picker. **Reload config** re-reads the project file.
- The **History** menu copies the project folder, `.dataverse-gen.json` or output folder path, and has
  **Clear selection**. Each item is disabled until there's something to act on.
- With no project open but a remembered folder, it shows "Last used: …" and explains that Browse reopens it.
- Once a project is open, a badge shows either ".dataverse-gen.json found" with the table, action and
  function counts, or "New project" (the file is created on the first generate).
