# ConfirmationDialog

A reusable modal dialog that asks the user to confirm an action that can't be undone. It only reports the
choice: the caller performs the action and controls whether the dialog is open and busy. Used by the
[LoadProjectDialog](./load-project-dialog.md) before deleting a saved project.

Source: [`src/components/dialogs/ConfirmationDialog.tsx`](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ConfirmationDialog.tsx)

## Props (`IConfirmationDialogProps`)

| Prop | Type | Description |
| --- | --- | --- |
| `open` | `boolean` | Whether the dialog is shown. |
| `title` | `string` | Dialog title, e.g. "Delete project?". |
| `message` | `ReactNode` | What will happen if the user confirms. A string is wrapped in `Text`. |
| `confirmLabel` | `string` | Label of the primary button, e.g. "Delete". |
| `busyLabel` | `string` (optional) | Primary button label while `busy`, e.g. "Deleting…". Defaults to `confirmLabel`. |
| `confirmIcon` | `ReactElement` (optional) | Icon on the primary button. |
| `cancelLabel` | `string` (optional) | Label of the secondary button. Defaults to "Cancel". |
| `busy` | `boolean` (optional) | Disables both buttons and blocks dismissing while the action runs. |
| `onConfirm` | `() => void` | Called by the primary button. |
| `onCancel` | `() => void` | Called by Cancel or the Escape key, unless `busy`. |

## Behavior

- Uses Fluent UI's `alert` dialog type (`role="alertdialog"`), the recommended type for destructive
  confirmations: a click outside the dialog doesn't dismiss it.
- Render it next to the dialog that uses it, not inside that dialog's `Dialog` element. A Fluent `Dialog`
  with two children treats the first as its trigger.
