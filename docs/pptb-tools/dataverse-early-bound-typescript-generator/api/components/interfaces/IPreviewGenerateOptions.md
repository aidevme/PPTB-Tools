# Interface: IPreviewGenerateOptions

Defined in: [components/cards/PreviewCard.tsx:31](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L31)

The Generate settings the Preview card shows as switches; each saves a tool-config key.

## Properties

### deleteOrphans

> **deleteOrphans**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:41](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L41)

Whether Generate also deletes orphaned files (the tool config's `deleteOrphanedFiles`).

***

### onDeleteOrphansChange

> **onDeleteOrphansChange**: (`checked`) => `void`

Defined in: [components/cards/PreviewCard.tsx:43](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L43)

Called with the new value when the Delete orphaned files switch is toggled; saves `deleteOrphanedFiles`.

#### Parameters

##### checked

`boolean`

#### Returns

`void`

***

### onRenameDuplicatesChange?

> `optional` **onRenameDuplicatesChange?**: (`checked`) => `void`

Defined in: [components/cards/PreviewCard.tsx:39](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L39)

The Rename duplicated identifier(s) switch; saves `renameDuplicateIdentifiers`. The switch is hidden without it.

#### Parameters

##### checked

`boolean`

#### Returns

`void`

***

### onSkipDuplicatesChange?

> `optional` **onSkipDuplicatesChange?**: (`checked`) => `void`

Defined in: [components/cards/PreviewCard.tsx:35](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L35)

The Skip duplicated identifier(s) switch; saves `skipDuplicateIdentifiers`. The switch is hidden without it.

#### Parameters

##### checked

`boolean`

#### Returns

`void`

***

### renameDuplicates?

> `optional` **renameDuplicates?**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:37](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L37)

Whether later duplicate enum members are renamed (the tool config's `renameDuplicateIdentifiers`).

***

### skipDuplicates?

> `optional` **skipDuplicates?**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:33](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L33)

Whether Generate leaves files with duplicate identifiers unwritten (the tool config's `skipDuplicateIdentifiers`).
