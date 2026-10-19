# Interface: IPreviewGenerateOptions

Defined in: [components/cards/PreviewCard.tsx:31](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L31)

The Generate settings the Preview card shows as switches; each saves a tool-config key.

## Properties

### customEnumTemplate?

> `optional` **customEnumTemplate?**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:44](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L44)

Whether the custom enum template is on (the tool config's `customEnumTemplate`).

#### Default Value

```ts
false
```

***

### deleteOrphans

> **deleteOrphans**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:56](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L56)

Whether Generate also deletes orphaned files (the tool config's `deleteOrphanedFiles`).

***

### generateTemplates?

> `optional` **generateTemplates?**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:49](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L49)

Whether Generate writes the templates (the tool config's `generateTemplates`); the proposal mentions when it's off.

#### Default Value

```ts
true
```

***

### onCustomEnumTemplateChange?

> `optional` **onCustomEnumTemplateChange?**: (`checked`) => `void`

Defined in: [components/cards/PreviewCard.tsx:54](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L54)

Saves `customEnumTemplate`: called with `true` when the custom enum template proposal is accepted. Without it, no
proposal is shown.

#### Parameters

##### checked

`boolean`

#### Returns

`void`

***

### onDeleteOrphansChange

> **onDeleteOrphansChange**: (`checked`) => `void`

Defined in: [components/cards/PreviewCard.tsx:58](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L58)

Called with the new value when the Delete orphaned files switch is toggled; saves `deleteOrphanedFiles`.

#### Parameters

##### checked

`boolean`

#### Returns

`void`

***

### onRenameDuplicatesChange?

> `optional` **onRenameDuplicatesChange?**: (`checked`) => `void`

Defined in: [components/cards/PreviewCard.tsx:39](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L39)

The Rename duplicated identifier(s) switch; saves `renameDuplicateIdentifiers`. The switch is hidden without it.

#### Parameters

##### checked

`boolean`

#### Returns

`void`

***

### onSkipDuplicatesChange?

> `optional` **onSkipDuplicatesChange?**: (`checked`) => `void`

Defined in: [components/cards/PreviewCard.tsx:35](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L35)

The Skip duplicated identifier(s) switch; saves `skipDuplicateIdentifiers`. The switch is hidden without it.

#### Parameters

##### checked

`boolean`

#### Returns

`void`

***

### renameDuplicates?

> `optional` **renameDuplicates?**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:37](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L37)

Whether later duplicate enum members are renamed (the tool config's `renameDuplicateIdentifiers`).

***

### skipDuplicates?

> `optional` **skipDuplicates?**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:33](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L33)

Whether Generate leaves files with duplicate identifiers unwritten (the tool config's `skipDuplicateIdentifiers`).
