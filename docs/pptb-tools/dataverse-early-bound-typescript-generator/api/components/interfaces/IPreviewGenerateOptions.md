# Interface: IPreviewGenerateOptions

Defined in: [components/cards/PreviewCard.tsx:31](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L31)

The Generate settings the Preview card shows as switches; each saves a tool-config key.

## Properties

### customEnumTemplate?

> `optional` **customEnumTemplate?**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:45](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L45)

Whether the project uses the custom enum template (its `pptbEarlyBoundGenerator.customEnumTemplate`, or the
Settings default).

#### Default Value

```ts
false
```

***

### deleteOrphans

> **deleteOrphans**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:57](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L57)

Whether Generate also deletes orphaned files (the tool config's `deleteOrphanedFiles`).

***

### generateTemplates?

> `optional` **generateTemplates?**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:50](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L50)

Whether Generate writes the templates (the tool config's `generateTemplates`); the proposal mentions when it's off.

#### Default Value

```ts
true
```

***

### onCustomEnumTemplateChange?

> `optional` **onCustomEnumTemplateChange?**: (`checked`) => `void`

Defined in: [components/cards/PreviewCard.tsx:55](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L55)

Saves the project's custom enum template: called with `true` when the proposal is accepted. Without it, no
proposal is shown.

#### Parameters

##### checked

`boolean`

#### Returns

`void`

***

### onDeleteOrphansChange

> **onDeleteOrphansChange**: (`checked`) => `void`

Defined in: [components/cards/PreviewCard.tsx:59](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L59)

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
