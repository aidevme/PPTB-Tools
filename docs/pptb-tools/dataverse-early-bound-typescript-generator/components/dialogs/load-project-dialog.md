# LoadProjectDialog

A modal dialog listing the projects saved with the [ProjectFormDialog](./project-form-dialog.md). It opens from the
**Load Existing Project** button on the [ProjectCard](../cards/project-card.md).

Source: [`src/components/dialogs/LoadProjectDialog.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx);
the table is
[`ProjectsTable.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/ProjectsTable.tsx),
and the columns and their sort order are in
[`projectColumns.ts`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/tables/projectColumns.ts).

## Props (`ILoadProjectDialogProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `open` | `boolean` | Whether the dialog is shown. |
| `onOpenChange` | `(open: boolean) => void` | Called when the dialog opens or closes. |
| `projects` | `ProjectEntry[]` | The saved projects (`projects` in the tool config). |
| `onLoad` | `(project: ProjectEntry) => Promise<boolean>` | Opens the chosen project. `true` closes the dialog, `false` (cancelled) keeps it open, and a rejection is shown as an error. |
| `onDelete` | `(project: ProjectEntry) => Promise<void>` | Removes the project from the saved list after the user confirms. A rejection is shown as an error. |
| `onCopy` | `(copy: NewProject) => Promise<void>` | Saves a copy as a new saved project (`App.tsx` passes `saveNewProject`). The copy form closes when it resolves, and the copy is selected once it's in `projects`; a rejection shows in the form. |
| `onEdit` | `(project: ProjectEntry, changes: NewProject) => Promise<void>` | Saves the name, description and location edited for the project. The edit dialog closes when it resolves and shows the error when it rejects. |
| `onBrowseLocation` | `(current: string) => Promise<string \| null>` | Opens PPTB's folder picker for the edited Location. Resolves to the folder, or `null` when cancelled. |

## Behavior

- **Title:** a folder icon on a brand-tinted tile, **Load Existing Project**, and the number of saved projects
  under it ("2 saved projects"). A close button (✕) on the right closes the dialog, like **Cancel**; it's disabled
  while a project is opening. The surface has a larger radius and shadow.
- Shows the saved projects in a Fluent UI `Table` with the columns **Name**, **Description**, **Version**,
  **Location**, **Created on** and **Modified on**, in a rounded frame. The header row is tinted and semibold and
  stays visible while the list scrolls. Each name has a folder icon, the version is a tinted `Badge`, the location
  is one line cut off with an ellipsis (the full path is in its tooltip), and the dates are muted.
- **Description** is cut off to fit the column. Hovering over or focusing it shows the full text in a Fluent UI
  `Tooltip`, keeping its line breaks. Projects without a description show a dash and no tooltip.
- **Sorting:** clicking a column header sorts by that column, ascending; clicking it again flips to
  descending. The dialog opens sorted by Name, ascending. Text ignores case, versions compare numerically
  (`1.0.10` after `1.0.9`), and dates by time. Rows that tie stay in name order.
- **Selecting:** one row at a time, by clicking the row or its radio button, or with Space or Enter. The
  selected row is highlighted.
- **Name** is a Fluent UI `Link`. Clicking it opens that project straight away, like selecting it and clicking
  **Load**.
- **Load** (with a folder icon) opens the selected project and is enabled once a row is selected.
- **Toolbar:** a Fluent UI `Toolbar` ("Project actions") above the table with **Copy** (`CopyRegular`), **Edit**
  (`EditRegular`) and **Delete** (`DeleteRegular`) `ToolbarButton`s, in that order. They act on the selected project, are disabled until a row is
  selected and while a project is opening or being deleted, and their tooltips name the selected project (or say
  to select one). At the toolbar's right end, "Selected: *name*" says which project they act on, or that none is
  selected yet. The table itself has no Copy, Edit or Delete buttons.
- **Copy** opens the [ProjectFormDialog](./project-form-dialog.md) titled **Copy project**, filled with the selected
  project's description and location and a name no saved project uses: *name* (copy), then *name* (copy 2) and so
  on (`copyName`). Change what you need; **Save** adds it as a new saved project (version 1.0.0, new dates), the
  Load Existing Project dialog stays open, and the copy is selected. Nothing is copied on disk, and the copy isn't
  opened.
- **Edit** opens the
  [ProjectFormDialog](./project-form-dialog.md) titled **Edit project**, filled with the project's name, description
  and location. The name can't match another saved project's. **Save** stores the changes (`App.tsx`'s
  `editProject` saves the updated list); the version and dates aren't changed, and a project that's open stays
  open at its current folder.
- **Delete** opens a [ConfirmationDialog](./confirmation-dialog.md). **Delete**
  there removes the project from the saved projects (`App.tsx`'s `deleteProject` saves the updated list);
  the files in its folder aren't touched. **Cancel** keeps it. Errors are shown in the dialog. **Cancel**, the Escape key, or a click outside closes the
  dialog. Nothing is selected when it opens.
- With no saved projects, an empty state (a folder icon in a dashed frame) says to create one with New Project;
  there's no toolbar or table.
- **Opening a project:** `App.tsx` (`openSavedProject`) sets the project's location as the project folder and
  reads its `.dataverse-gen.json`, like **Reload config**, then the dialog closes. A PPTB info notification
  (5 seconds) confirms it: "*Project* loaded", with the table, action and function counts, or that there's no
  `.dataverse-gen.json` yet.
- **If PPTB refuses access** to that folder (it may only allow folders picked in the current session), the
  folder picker opens at the saved location for the user to confirm, and the confirmed folder is loaded.
  Cancelling the picker leaves the dialog open. Other errors, such as a folder that no longer exists, are
  shown in the dialog.
