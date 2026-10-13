# LoadProjectDialog

A modal dialog listing the projects saved with the [NewProjectDialog](./new-project-dialog.md). It opens from the
**Load Existing Project** button on the [ProjectCard](./project-card.md).

Source: [`src/components/dialogs/LoadProjectDialog.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx)

## Props (`ILoadProjectDialogProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `open` | `boolean` | Whether the dialog is shown. |
| `onOpenChange` | `(open: boolean) => void` | Called when the dialog opens or closes. |
| `projects` | `ProjectEntry[]` | The saved projects (`projects` in the tool config). |
| `onLoad` | `(project: ProjectEntry) => Promise<boolean>` | Opens the chosen project. `true` closes the dialog, `false` (cancelled) keeps it open, and a rejection is shown as an error. |
| `onDelete` | `(project: ProjectEntry) => Promise<void>` | Removes the project from the saved list after the user confirms. A rejection is shown as an error. |

## Behavior

- Shows the saved projects in a Fluent UI `Table` with the columns **Name**, **Description**, **Version**,
  **Location**, **Created On** and **Modified On**. Header cells are semibold.
- **Sorting:** clicking a column header sorts by that column, ascending; clicking it again flips to
  descending. The dialog opens sorted by Name, ascending. Text ignores case, versions compare numerically
  (`1.0.10` after `1.0.9`), and dates by time. Rows that tie stay in name order.
- **Selecting:** one row at a time, by clicking the row or its radio button, or with Space or Enter. The
  selected row is highlighted.
- **Name** is a Fluent UI `Link`. Clicking it opens that project straight away, like selecting it and clicking
  **Load**.
- **Load** opens the selected project and is enabled once a row is selected.
- **Delete:** each row ends with a subtle Fluent UI `Button` with a trash icon (`DeleteRegular`) and a
  "Delete project" `Tooltip`. Clicking it doesn't select the row; it opens a
  [ConfirmationDialog](./confirmation-dialog.md). **Delete**
  there removes the project from the saved projects (`App.tsx`'s `deleteProject` saves the updated list);
  the files in its folder aren't touched. **Cancel** keeps it. Errors are shown in the dialog. **Cancel**, the Escape key, or a click outside closes the
  dialog. Nothing is selected when it opens.
- With no saved projects, it says to create one with New Project.
- **Opening a project:** `App.tsx` (`openSavedProject`) sets the project's location as the project folder and
  reads its `.dataverse-gen.json`, like **Reload config**, then the dialog closes.
- **If PPTB refuses access** to that folder (it may only allow folders picked in the current session), the
  folder picker opens at the saved location for the user to confirm, and the confirmed folder is loaded.
  Cancelling the picker leaves the dialog open. Other errors, such as a folder that no longer exists, are
  shown in the dialog.
