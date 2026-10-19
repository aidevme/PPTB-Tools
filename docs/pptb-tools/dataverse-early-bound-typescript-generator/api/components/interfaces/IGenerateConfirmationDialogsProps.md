# Interface: IGenerateConfirmationDialogsProps

Defined in: [components/dialogs/GenerateConfirmations.tsx:58](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/GenerateConfirmations.tsx#L58)

Props for [GenerateConfirmationDialogs](../functions/GenerateConfirmationDialogs.md).

## Properties

### deleteOpen

> **deleteOpen**: `boolean`

Defined in: [components/dialogs/GenerateConfirmations.tsx:64](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/GenerateConfirmations.tsx#L64)

The Delete orphaned files confirmation is open.

***

### generateOpen

> **generateOpen**: `boolean`

Defined in: [components/dialogs/GenerateConfirmations.tsx:70](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/GenerateConfirmations.tsx#L70)

The "Ask before generating" confirmation is open.

***

### onCancelDelete

> **onCancelDelete**: () => `void`

Defined in: [components/dialogs/GenerateConfirmations.tsx:68](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/GenerateConfirmations.tsx#L68)

Called when the Delete orphaned files confirmation is cancelled or dismissed with Escape.

#### Returns

`void`

***

### onCancelGenerate

> **onCancelGenerate**: () => `void`

Defined in: [components/dialogs/GenerateConfirmations.tsx:74](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/GenerateConfirmations.tsx#L74)

Called when the "Ask before generating" confirmation is cancelled or dismissed with Escape.

#### Returns

`void`

***

### onConfirmDelete

> **onConfirmDelete**: () => `void`

Defined in: [components/dialogs/GenerateConfirmations.tsx:66](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/GenerateConfirmations.tsx#L66)

Called when the Delete orphaned files confirmation is accepted (its button also names pending writes).

#### Returns

`void`

***

### onConfirmGenerate

> **onConfirmGenerate**: () => `void`

Defined in: [components/dialogs/GenerateConfirmations.tsx:72](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/GenerateConfirmations.tsx#L72)

Called when the "Ask before generating" confirmation is accepted.

#### Returns

`void`

***

### plan

> **plan**: [`WritePlan`](../../types/interfaces/WritePlan.md) \| `null`

Defined in: [components/dialogs/GenerateConfirmations.tsx:60](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/GenerateConfirmations.tsx#L60)

The write plan the confirmations describe; neither dialog opens while it's `null`.

***

### skipDuplicates

> **skipDuplicates**: `boolean`

Defined in: [components/dialogs/GenerateConfirmations.tsx:62](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/dialogs/GenerateConfirmations.tsx#L62)

Whether files with duplicate identifiers are left unwritten; changes the counts and the duplicate warning.
