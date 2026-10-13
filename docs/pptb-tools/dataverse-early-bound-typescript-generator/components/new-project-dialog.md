# NewProjectDialog

A modal dialog for creating a new project. It opens from the **New Project** button on the
[ProjectCard](./project-card.md).

Source: [`src/components/dialogs/NewProjectDialog.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/NewProjectDialog.tsx)

## Props (`INewProjectDialogProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `open` | `boolean` | Whether the dialog is shown. |
| `onOpenChange` | `(open: boolean) => void` | Called when the dialog opens or closes. |
| `existingNames` | `string[]` | Names of saved projects; a new project can't reuse one. |
| `onBrowseLocation` | `(current: string) => Promise<string \| null>` | Opens PPTB's folder picker for Location. Resolves to the folder, or `null` when cancelled. |
| `onSave` | `(project: NewProject) => Promise<void>` | Saves the project. The dialog closes when it resolves and shows the error when it rejects. |

`NewProject` is `{ name, description, location }`. `App.tsx` adds an `id`, a `version` (`1.0.0`) and
`createdOn` and `modifiedOn` timestamps (both the creation time) before saving. Projects saved before
`version` and `modifiedOn` existed get those same defaults when they load.

## Version and Modified On

After each successful Generate of a saved project's folder, the tool compares the files the
run produced with the ones the project's previous run produced (`lastGeneratedFiles`). If any file was
added, or a previously generated file is no longer produced (an orphan), the version gets a patch bump
(`1.0.0` → `1.0.1`) and **Modified On** is set to now. Changes to the content of the same files don't count.

- **First run:** with no previous list, the files the run created on disk count as added.
- **Which project:** the open folder is matched to a saved project by location, ignoring separators and, on
  Windows, casing. Folders that aren't saved projects aren't tracked.
- If saving the updated project fails, the generated files are still written; the error is logged.

## Fields

| Field | Required | Notes |
| --- | --- | --- |
| Project Name | Yes | Trimmed. Can't match an existing project's name, ignoring case. |
| Description | No | Multi-line. |
| Location | Yes | A folder path. Type it, or pick it with **Browse…**. |

## Behavior

- The form is empty each time the dialog opens.
- **Save** is enabled once Project Name and Location are filled in and the name isn't already used. It saves
  and closes the dialog, or shows the error and stays open if saving fails.
- **Cancel**, the Escape key, or a click outside the dialog closes it without saving.
- **Where projects are saved:** `App.tsx` appends the project to `projects` in the tool config and saves it in
  PPTB's per-tool settings (`toolboxAPI.settings`, key `toolConfig`), the same place as the
  [SettingsPanel](./settings-panel.md) values. `projects` defaults to `[]` in
  `src/config/dataverse-early-bound-typescript-generator-config.json`. The tool can't write that file at
  runtime.
- Creating a project doesn't open it or create any files yet.
