# Interface: IPathChipProps

Defined in: [components/shared/PathChip.tsx:7](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/PathChip.tsx#L7)

Props for [PathChip](../functions/PathChip.md).

## Properties

### appearance?

> `optional` **appearance?**: `"plain"` \| `"filled"`

Defined in: [components/shared/PathChip.tsx:17](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/PathChip.tsx#L17)

`plain` is monospace text that truncates; `filled` adds a neutral background. Defaults to `plain`.

***

### label

> **label**: `string`

Defined in: [components/shared/PathChip.tsx:11](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/PathChip.tsx#L11)

What the path is, for example "Project folder path": the copy notification's label and, lowercased, the copy button's tooltip.

***

### maxLength?

> `optional` **maxLength?**: `number`

Defined in: [components/shared/PathChip.tsx:15](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/PathChip.tsx#L15)

Longest text shown before the middle of the path is shortened; defaults to `shortenPath`'s 48.

***

### onCopy

> **onCopy**: (`path`, `label`) => `void`

Defined in: [components/shared/PathChip.tsx:13](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/PathChip.tsx#L13)

Called with the full `path` and the `label` when the copy button is clicked; the parent does the copying.

#### Parameters

##### path

`string`

##### label

`string`

#### Returns

`void`

***

### path

> **path**: `string`

Defined in: [components/shared/PathChip.tsx:9](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/PathChip.tsx#L9)

The full path: shown shortened, in full in the tooltip, and copied by the copy button.
