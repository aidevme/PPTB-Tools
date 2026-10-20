# Interface: IPreviewCardProps

Defined in: [components/cards/PreviewCard.tsx:73](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L73)

Props for [PreviewCard](../functions/PreviewCard.md).

## Properties

### busy

> **busy**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:85](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L85)

Work in progress: disables the buttons and switches, and shows a loading skeleton while there's no plan yet.

***

### canPreview

> **canPreview**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:81](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L81)

Enables Preview and the stale warning's Preview again; the app sets it once connected, with a selection.

***

### generateOptions

> **generateOptions**: [`IPreviewGenerateOptions`](IPreviewGenerateOptions.md)

Defined in: [components/cards/PreviewCard.tsx:91](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L91)

The Generate settings shown as switches in the action bar.

***

### lastResult

> **lastResult**: `string` \| `null`

Defined in: [components/cards/PreviewCard.tsx:89](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L89)

Summary of the last Generate run, shown as a success message until the next preview.

***

### needsProject

> **needsProject**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:83](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L83)

True when everything is ready except the project folder; shows a hint next to the buttons.

***

### now?

> `optional` **now?**: `number`

Defined in: [components/cards/PreviewCard.tsx:99](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L99)

Current time for relative dates; a parameter so tests get stable output.

***

### onCopyText

> **onCopyText**: (`text`, `label`) => `void`

Defined in: [components/cards/PreviewCard.tsx:97](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L97)

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

Defined in: [components/cards/PreviewCard.tsx:95](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L95)

Called when Generate is clicked; the caller confirms where needed, then writes (and deletes) the files.

#### Returns

`void`

***

### onPreview

> **onPreview**: () => `void`

Defined in: [components/cards/PreviewCard.tsx:93](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L93)

Called when Preview or Preview again is clicked, to compute a new plan.

#### Returns

`void`

***

### plan

> **plan**: [`WritePlan`](../../types/interfaces/WritePlan.md) \| `null`

Defined in: [components/cards/PreviewCard.tsx:77](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L77)

The last computed write plan, or `null` before the first preview (the list shows a placeholder).

***

### previewedAt

> **previewedAt**: `string` \| `null`

Defined in: [components/cards/PreviewCard.tsx:87](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L87)

When the current plan was computed (ISO), for "Previewed … ago".

***

### stale

> **stale**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:79](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L79)

Whether the plan is stale because the selection or options changed since it was computed.

***

### step

> **step**: [`StepState`](StepState.md)

Defined in: [components/cards/PreviewCard.tsx:75](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L75)

The card's step in the workflow: number, title and completion badge.
