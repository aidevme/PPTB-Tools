# ProjectCard

Step 1 of the workflow: pick the project folder and show whether it already has a `.dataverse-gen.json`.

Source: [`src/components/cards/ProjectCard.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/ProjectCard.tsx)

## Props (`ProjectCardProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `projectRoot` | `string \| null` | The open project folder. |
| `rememberedFolder` | `string \| null` | Folder used last time with this connection, shown as a hint while no project is open. |
| `configState` | `ProjectConfigState \| null` | The loaded `.dataverse-gen.json`, its path, and whether it exists. |
| `busy` | `boolean` | Disables the buttons while another operation runs. |
| `onNewProject` | `() => void` | Opens the [NewProjectDialog](./new-project-dialog.md). |
| `onLoadExistingProject` | `() => void` | Opens the [LoadProjectDialog](./load-project-dialog.md). |
| `onReload` | `() => void` | Re-reads `.dataverse-gen.json` from disk. |
| `outputFolder` | `string \| null` | Absolute output folder (`output.outputRoot` resolved against the project). |
| `hasSelection` | `boolean` | Whether anything is selected, enabling "Clear selection". |
| `onCopyPath` | `(path: string, label: string) => void` | Copies a path to the clipboard; `label` names it in the confirmation toast. |
| `onClearSelection` | `() => void` | Clears every selected table, action and function. |

## Behavior

- **New Project** opens the [NewProjectDialog](./new-project-dialog.md), and **Load Existing Project** opens the
  [LoadProjectDialog](./load-project-dialog.md). These are the way to open a project folder; there's no
  Browse… button.
- **Reload config** re-reads the project file.
- The **History** menu copies the project folder, `.dataverse-gen.json` or output folder path, and has
  **Clear selection**. Each item is disabled until there's something to act on. The menu is currently
  hidden; set `SHOW_HISTORY_MENU` to `true` in `ProjectCard.tsx` to show it again.
- With no project open but a remembered folder, it shows "Last used: …" and points to Load Existing Project.
- Once a project is open, a badge shows either ".dataverse-gen.json found" with the table, action and
  function counts, or "New project" (the file is created on the first generate).
