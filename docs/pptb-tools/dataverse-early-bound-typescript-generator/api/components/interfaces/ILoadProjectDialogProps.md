# Interface: ILoadProjectDialogProps

Defined in: [components/dialogs/LoadProjectDialog.tsx:30](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L30)

Props for [LoadProjectDialog](../functions/LoadProjectDialog.md).

## Properties

### onBrowseLocation

> **onBrowseLocation**: (`current`) => `Promise`\<`string` \| `null`\>

Defined in: [components/dialogs/LoadProjectDialog.tsx:61](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L61)

Opens the folder picker for the edited Location; resolves to the chosen folder, or `null` when cancelled.

#### Parameters

##### current

`string`

#### Returns

`Promise`\<`string` \| `null`\>

***

### onCopy

> **onCopy**: (`copy`) => `Promise`\<`void`\>

Defined in: [components/dialogs/LoadProjectDialog.tsx:59](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L59)

Saves a copy of a project as a new saved project, with the name, description and location from the copy form.
The form closes when it resolves (the copy is then selected) and shows the error when it rejects.

#### Parameters

##### copy

[`NewProject`](../type-aliases/NewProject.md)

#### Returns

`Promise`\<`void`\>

***

### onDelete

> **onDelete**: (`project`) => `Promise`\<`void`\>

Defined in: [components/dialogs/LoadProjectDialog.tsx:49](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L49)

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

Defined in: [components/dialogs/LoadProjectDialog.tsx:54](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L54)

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

Defined in: [components/dialogs/LoadProjectDialog.tsx:44](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L44)

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

Defined in: [components/dialogs/LoadProjectDialog.tsx:37](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L37)

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

Defined in: [components/dialogs/LoadProjectDialog.tsx:32](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L32)

Shows the dialog; each time it opens, the selection, error, sort and any pending delete or edit are reset.

***

### projects

> **projects**: [`ProjectEntry`](../../config/interfaces/ProjectEntry.md)[]

Defined in: [components/dialogs/LoadProjectDialog.tsx:39](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/LoadProjectDialog.tsx#L39)

Projects saved with the New Project dialog.
