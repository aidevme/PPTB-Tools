# Interface: IPreviewCardProps

Defined in: [components/cards/PreviewCard.tsx:62](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L62)

Props for [PreviewCard](../functions/PreviewCard.md).

## Properties

### busy

> **busy**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:74](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L74)

Work in progress: disables the buttons and switches, and shows a loading skeleton while there's no plan yet.

***

### canPreview

> **canPreview**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:70](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L70)

Enables Preview and the stale warning's Preview again; the app sets it once connected, with a selection.

***

### generateOptions

> **generateOptions**: [`IPreviewGenerateOptions`](IPreviewGenerateOptions.md)

Defined in: [components/cards/PreviewCard.tsx:80](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L80)

The Generate settings shown as switches in the action bar.

***

### lastResult

> **lastResult**: `string` \| `null`

Defined in: [components/cards/PreviewCard.tsx:78](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L78)

Summary of the last Generate run, shown as a success message until the next preview.

***

### needsProject

> **needsProject**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:72](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L72)

True when everything is ready except the project folder; shows a hint next to the buttons.

***

### now?

> `optional` **now?**: `number`

Defined in: [components/cards/PreviewCard.tsx:88](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L88)

Current time for relative dates; a parameter so tests get stable output.

***

### onCopyText

> **onCopyText**: (`text`, `label`) => `void`

Defined in: [components/cards/PreviewCard.tsx:86](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L86)

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

Defined in: [components/cards/PreviewCard.tsx:84](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L84)

Called when Generate is clicked; the caller confirms where needed, then writes (and deletes) the files.

#### Returns

`void`

***

### onPreview

> **onPreview**: () => `void`

Defined in: [components/cards/PreviewCard.tsx:82](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L82)

Called when Preview or Preview again is clicked, to compute a new plan.

#### Returns

`void`

***

### plan

> **plan**: [`WritePlan`](../../types/interfaces/WritePlan.md) \| `null`

Defined in: [components/cards/PreviewCard.tsx:66](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L66)

The last computed write plan, or `null` before the first preview (the list shows a placeholder).

***

### previewedAt

> **previewedAt**: `string` \| `null`

Defined in: [components/cards/PreviewCard.tsx:76](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L76)

When the current plan was computed (ISO), for "Previewed … ago".

***

### stale

> **stale**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:68](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L68)

Whether the plan is stale because the selection or options changed since it was computed.

***

### step

> **step**: [`StepState`](StepState.md)

Defined in: [components/cards/PreviewCard.tsx:64](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L64)

The card's step in the workflow: number, title and completion badge.
