# Interface: IProjectFormDialogProps

Defined in: [components/dialogs/ProjectFormDialog.tsx:26](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L26)

Props for [ProjectFormDialog](../functions/ProjectFormDialog.md).

## Properties

### existingNames

> **existingNames**: `string`[]

Defined in: [components/dialogs/ProjectFormDialog.tsx:35](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L35)

Names of the other saved projects; the project can't reuse one (case-insensitive).

***

### onBrowseLocation

> **onBrowseLocation**: (`current`) => `Promise`\<`string` \| `null`\>

Defined in: [components/dialogs/ProjectFormDialog.tsx:39](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L39)

Opens the folder picker for Location; resolves to the chosen folder, or `null` when cancelled.

#### Parameters

##### current

`string`

#### Returns

`Promise`\<`string` \| `null`\>

***

### onOpenChange

> **onOpenChange**: (`open`) => `void`

Defined in: [components/dialogs/ProjectFormDialog.tsx:33](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L33)

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

Defined in: [components/dialogs/ProjectFormDialog.tsx:41](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L41)

Saves the project. The dialog closes when it resolves and shows the error when it rejects.

#### Parameters

##### project

[`NewProject`](../type-aliases/NewProject.md)

#### Returns

`Promise`\<`void`\>

***

### open

> **open**: `boolean`

Defined in: [components/dialogs/ProjectFormDialog.tsx:28](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L28)

Shows the dialog; each time it opens, the form starts empty or with `project`'s values.

***

### project?

> `optional` **project?**: [`ProjectEntry`](../../config/interfaces/ProjectEntry.md)

Defined in: [components/dialogs/ProjectFormDialog.tsx:37](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ProjectFormDialog.tsx#L37)

The saved project to edit. Omitted for a new project.
