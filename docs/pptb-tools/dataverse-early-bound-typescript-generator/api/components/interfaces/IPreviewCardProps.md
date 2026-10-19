# Interface: IPreviewCardProps

Defined in: [components/cards/PreviewCard.tsx:47](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L47)

Props for [PreviewCard](../functions/PreviewCard.md).

## Properties

### busy

> **busy**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:59](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L59)

Work in progress: disables the buttons and switches, and shows a loading skeleton while there's no plan yet.

***

### canPreview

> **canPreview**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:55](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L55)

Enables Preview and the stale warning's Preview again; the app sets it once connected, with a selection.

***

### generateOptions

> **generateOptions**: [`IPreviewGenerateOptions`](IPreviewGenerateOptions.md)

Defined in: [components/cards/PreviewCard.tsx:65](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L65)

The Generate settings shown as switches in the action bar.

***

### lastResult

> **lastResult**: `string` \| `null`

Defined in: [components/cards/PreviewCard.tsx:63](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L63)

Summary of the last Generate run, shown as a success message until the next preview.

***

### needsProject

> **needsProject**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:57](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L57)

True when everything is ready except the project folder; shows a hint next to the buttons.

***

### now?

> `optional` **now?**: `number`

Defined in: [components/cards/PreviewCard.tsx:73](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L73)

Current time for relative dates; a parameter so tests get stable output.

***

### onCopyText

> **onCopyText**: (`text`, `label`) => `void`

Defined in: [components/cards/PreviewCard.tsx:71](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L71)

Copies text (a file's content or a path) to the clipboard; `label` names it in the confirmation.

#### Parameters

##### text

`string`

##### label

`string`

#### Returns

`void`

***

### onGenerate

> **onGenerate**: () => `void`

Defined in: [components/cards/PreviewCard.tsx:69](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L69)

Called when Generate is clicked; the caller confirms where needed, then writes (and deletes) the files.

#### Returns

`void`

***

### onPreview

> **onPreview**: () => `void`

Defined in: [components/cards/PreviewCard.tsx:67](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L67)

Called when Preview or Preview again is clicked, to compute a new plan.

#### Returns

`void`

***

### plan

> **plan**: [`WritePlan`](../../types/interfaces/WritePlan.md) \| `null`

Defined in: [components/cards/PreviewCard.tsx:51](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L51)

The last computed write plan, or `null` before the first preview (the list shows a placeholder).

***

### previewedAt

> **previewedAt**: `string` \| `null`

Defined in: [components/cards/PreviewCard.tsx:61](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L61)

When the current plan was computed (ISO), for "Previewed … ago".

***

### stale

> **stale**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:53](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L53)

Whether the plan is stale because the selection or options changed since it was computed.

***

### step

> **step**: [`StepState`](StepState.md)

Defined in: [components/cards/PreviewCard.tsx:49](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L49)

The card's step in the workflow: number, title and completion badge.
