# Function: ProjectFormDialog()

> **ProjectFormDialog**(`__namedParameters`): `Element`

Defined in: [components/dialogs/ProjectFormDialog.tsx:79](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L79)

Modal dialog for a project's name, description and location, saved with Save. Creates a new project, edits
`project` when one is given, or creates a copy of `copyOf` (filled in from it, with a free name).

## Parameters

### \_\_namedParameters

[`IProjectFormDialogProps`](../interfaces/IProjectFormDialogProps.md)

## Returns

`Element`

## Remarks

The title has an icon (a folder with a plus, a pencil when editing, two pages when copying), a subtitle saying what
the dialog does, and
a close button. The name and location inputs have icons and the location is monospace; when editing, a strip
under the fields shows the project's version, created and modified dates, which the dialog doesn't change.
