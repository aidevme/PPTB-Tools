# Interface: IProjectFormDialogProps

Defined in: [components/dialogs/ProjectFormDialog.tsx:29](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L29)

Props for [ProjectFormDialog](../functions/ProjectFormDialog.md).

## Properties

### copyOf?

> `optional` **copyOf?**: [`ProjectEntry`](../../config/interfaces/ProjectEntry.md)

Defined in: [components/dialogs/ProjectFormDialog.tsx:45](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L45)

The saved project to copy, when `project` isn't set: the form starts with its description and location and a
name that isn't used yet (see copyName), and Save creates a new project.

***

### existingNames

> **existingNames**: `string`[]

Defined in: [components/dialogs/ProjectFormDialog.tsx:38](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L38)

Names of the other saved projects; the project can't reuse one (case-insensitive).

***

### onBrowseLocation

> **onBrowseLocation**: (`current`) => `Promise`\<`string` \| `null`\>

Defined in: [components/dialogs/ProjectFormDialog.tsx:47](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L47)

Opens the folder picker for Location; resolves to the chosen folder, or `null` when cancelled.

#### Parameters

##### current

`string`

#### Returns

`Promise`\<`string` \| `null`\>

***

### onOpenChange

> **onOpenChange**: (`open`) => `void`

Defined in: [components/dialogs/ProjectFormDialog.tsx:36](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L36)

Called with `false` when the dialog asks to close (Cancel, Escape, or after a successful save); not called
while saving.

#### Parameters

##### open

`boolean`

#### Returns

`void`

***

### onSave

> **onSave**: (`project`) => `Promise`\<`void`\>

Defined in: [components/dialogs/ProjectFormDialog.tsx:49](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L49)

Saves the project. The dialog closes when it resolves and shows the error when it rejects.

#### Parameters

##### project

[`NewProject`](../type-aliases/NewProject.md)

#### Returns

`Promise`\<`void`\>

***

### open

> **open**: `boolean`

Defined in: [components/dialogs/ProjectFormDialog.tsx:31](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L31)

Shows the dialog; each time it opens, the form starts empty or with `project`'s values.

***

### project?

> `optional` **project?**: [`ProjectEntry`](../../config/interfaces/ProjectEntry.md)

Defined in: [components/dialogs/ProjectFormDialog.tsx:40](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L40)

The saved project to edit. Omitted for a new project.
