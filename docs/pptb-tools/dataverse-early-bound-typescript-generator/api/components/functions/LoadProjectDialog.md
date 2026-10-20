# Function: LoadProjectDialog()

> **LoadProjectDialog**(`__namedParameters`): `Element`

Defined in: [components/dialogs/LoadProjectDialog.tsx:74](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L74)

Modal dialog listing the saved projects in a table with single-row selection. Load opens the selected
project; clicking a project's name opens it directly. The toolbar above the table copies, edits or deletes the
selected project; its buttons are disabled until a row is selected, and while a project is opening or being
deleted. Copy opens the project form filled in from the selected project, with a name that isn't used yet.

## Parameters

### \_\_namedParameters

[`ILoadProjectDialogProps`](../interfaces/ILoadProjectDialogProps.md)

## Returns

`Element`

## Remarks

The title has an icon, the number of saved projects, and a close button; the toolbar says which project is
selected; with no saved projects, an empty state says to create one with New Project.
