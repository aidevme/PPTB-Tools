# Interface: ILoadProjectDialogProps

Defined in: [components/dialogs/LoadProjectDialog.tsx:14](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L14)

Props for [LoadProjectDialog](../functions/LoadProjectDialog.md).

## Properties

### onBrowseLocation

> **onBrowseLocation**: (`current`) => `Promise`\<`string` \| `null`\>

Defined in: [components/dialogs/LoadProjectDialog.tsx:40](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L40)

Opens the folder picker for the edited Location; resolves to the chosen folder, or `null` when cancelled.

#### Parameters

##### current

`string`

#### Returns

`Promise`\<`string` \| `null`\>

***

### onDelete

> **onDelete**: (`project`) => `Promise`\<`void`\>

Defined in: [components/dialogs/LoadProjectDialog.tsx:33](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L33)

Removes the project from the saved list (its files are left alone). Called after the user confirms;
a rejection is shown as an error.

#### Parameters

##### project

[`ProjectEntry`](../../config/interfaces/ProjectEntry.md)

#### Returns

`Promise`\<`void`\>

***

### onEdit

> **onEdit**: (`project`, `changes`) => `Promise`\<`void`\>

Defined in: [components/dialogs/LoadProjectDialog.tsx:38](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L38)

Saves the name, description and location edited for the project. The edit dialog closes when it resolves
and shows the error when it rejects.

#### Parameters

##### project

[`ProjectEntry`](../../config/interfaces/ProjectEntry.md)

##### changes

[`NewProject`](../type-aliases/NewProject.md)

#### Returns

`Promise`\<`void`\>

***

### onLoad

> **onLoad**: (`project`) => `Promise`\<`boolean`\>

Defined in: [components/dialogs/LoadProjectDialog.tsx:28](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L28)

Opens the chosen project. Resolves to `true` once it's being opened (the dialog closes), `false` when the
user cancelled (the dialog stays open), and rejects with an error to show.

#### Parameters

##### project

[`ProjectEntry`](../../config/interfaces/ProjectEntry.md)

#### Returns

`Promise`\<`boolean`\>

***

### onOpenChange

> **onOpenChange**: (`open`) => `void`

Defined in: [components/dialogs/LoadProjectDialog.tsx:21](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L21)

Called with `false` when the dialog asks to close (Cancel, Escape, or after a project is opened); ignored
while a project is loading.

#### Parameters

##### open

`boolean`

#### Returns

`void`

***

### open

> **open**: `boolean`

Defined in: [components/dialogs/LoadProjectDialog.tsx:16](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L16)

Shows the dialog; each time it opens, the selection, error, sort and any pending delete or edit are reset.

***

### projects

> **projects**: [`ProjectEntry`](../../config/interfaces/ProjectEntry.md)[]

Defined in: [components/dialogs/LoadProjectDialog.tsx:23](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L23)

Projects saved with the New Project dialog.
