# Interface: IConfirmationDialogProps

Defined in: [components/dialogs/ConfirmationDialog.tsx:5](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ConfirmationDialog.tsx#L5)

Props for [ConfirmationDialog](../functions/ConfirmationDialog.md).

## Properties

### busy?

> `optional` **busy?**: `boolean`

Defined in: [components/dialogs/ConfirmationDialog.tsx:27](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ConfirmationDialog.tsx#L27)

While true, both buttons are disabled and the dialog can't be dismissed.

#### Default Value

```ts
false
```

***

### busyLabel?

> `optional` **busyLabel?**: `string`

Defined in: [components/dialogs/ConfirmationDialog.tsx:15](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ConfirmationDialog.tsx#L15)

Label shown on the confirm button while `busy`, e.g. "Deleting…". Defaults to `confirmLabel`.

***

### cancelLabel?

> `optional` **cancelLabel?**: `string`

Defined in: [components/dialogs/ConfirmationDialog.tsx:22](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ConfirmationDialog.tsx#L22)

Label of the cancel button.

#### Default Value

`'Cancel'`

***

### confirmIcon?

> `optional` **confirmIcon?**: `ReactElement`\<`any`, `string` \| `JSXElementConstructor`\<`any`\>\>

Defined in: [components/dialogs/ConfirmationDialog.tsx:17](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ConfirmationDialog.tsx#L17)

Optional icon for the confirm button.

***

### confirmLabel

> **confirmLabel**: `string`

Defined in: [components/dialogs/ConfirmationDialog.tsx:13](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ConfirmationDialog.tsx#L13)

Label of the confirm button, e.g. "Delete".

***

### message

> **message**: `ReactNode`

Defined in: [components/dialogs/ConfirmationDialog.tsx:11](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ConfirmationDialog.tsx#L11)

What will happen if the user confirms.

***

### onCancel

> **onCancel**: () => `void`

Defined in: [components/dialogs/ConfirmationDialog.tsx:31](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ConfirmationDialog.tsx#L31)

Called by Cancel or the Escape key (unless `busy`). An alert dialog ignores clicks outside it.

#### Returns

`void`

***

### onConfirm

> **onConfirm**: () => `void`

Defined in: [components/dialogs/ConfirmationDialog.tsx:29](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ConfirmationDialog.tsx#L29)

Called when the confirm button is clicked; the caller performs the action.

#### Returns

`void`

***

### open

> **open**: `boolean`

Defined in: [components/dialogs/ConfirmationDialog.tsx:7](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ConfirmationDialog.tsx#L7)

Shows the dialog; the caller controls it and closes it from `onConfirm` or `onCancel`.

***

### title

> **title**: `string`

Defined in: [components/dialogs/ConfirmationDialog.tsx:9](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/ConfirmationDialog.tsx#L9)

The dialog's title, usually a question such as "Delete project?".
