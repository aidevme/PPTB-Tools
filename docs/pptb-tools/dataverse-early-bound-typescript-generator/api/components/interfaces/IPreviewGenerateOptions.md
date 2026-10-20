# Interface: IPreviewGenerateOptions

Defined in: [components/cards/PreviewCard.tsx:32](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L32)

The Generate settings the Preview card shows as switches; each saves a tool-config key.

## Properties

### customEnumTemplate?

> `optional` **customEnumTemplate?**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:46](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L46)

Whether the project uses the custom enum template (its `pptbEarlyBoundGenerator.customEnumTemplate`, or the
Settings default).

#### Default Value

```ts
false
```

***

### customTemplates?

> `optional` **customTemplates?**: [`CustomTemplateSelection`](../../core/type-aliases/CustomTemplateSelection.md)

Defined in: [components/cards/PreviewCard.tsx:58](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L58)

The project's Custom Templates choices (`pptbEarlyBoundGenerator.customTemplates`).

***

### customTemplatesDisabled?

> `optional` **customTemplatesDisabled?**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:65](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L65)

Disables the Custom Templates button, for example before a project is open.

#### Default Value

```ts
false
```

***

### deleteOrphans

> **deleteOrphans**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:67](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L67)

Whether Generate also deletes orphaned files (the tool config's `deleteOrphanedFiles`).

***

### generateTemplates?

> `optional` **generateTemplates?**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:51](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L51)

Whether Generate writes the templates (the tool config's `generateTemplates`); the proposal mentions when it's off.

#### Default Value

```ts
true
```

***

### onCustomEnumTemplateChange?

> `optional` **onCustomEnumTemplateChange?**: (`checked`) => `void`

Defined in: [components/cards/PreviewCard.tsx:56](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L56)

Saves the project's custom enum template: called with `true` when the proposal is accepted. Without it, no
proposal is shown.

#### Parameters

##### checked

`boolean`

#### Returns

`void`

***

### onCustomTemplatesChange?

> `optional` **onCustomTemplatesChange?**: (`selection`) => `void`

Defined in: [components/cards/PreviewCard.tsx:60](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L60)

Saves the project's Custom Templates choices. The Custom Templates button is hidden without it.

#### Parameters

##### selection

[`CustomTemplateSelection`](../../core/type-aliases/CustomTemplateSelection.md)

#### Returns

`void`

***

### onDeleteOrphansChange

> **onDeleteOrphansChange**: (`checked`) => `void`

Defined in: [components/cards/PreviewCard.tsx:69](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L69)

Called with the new value when the Delete orphaned files switch is toggled; saves `deleteOrphanedFiles`.

#### Parameters

##### checked

`boolean`

#### Returns

`void`

***

### onRenameDuplicatesChange?

> `optional` **onRenameDuplicatesChange?**: (`checked`) => `void`

Defined in: [components/cards/PreviewCard.tsx:40](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L40)

The Rename duplicated identifier(s) switch; saves `renameDuplicateIdentifiers`. The switch is hidden without it.

#### Parameters

##### checked

`boolean`

#### Returns

`void`

***

### onSkipDuplicatesChange?

> `optional` **onSkipDuplicatesChange?**: (`checked`) => `void`

Defined in: [components/cards/PreviewCard.tsx:36](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L36)

The Skip duplicated identifier(s) switch; saves `skipDuplicateIdentifiers`. The switch is hidden without it.

#### Parameters

##### checked

`boolean`

#### Returns

`void`

***

### renameDuplicates?

> `optional` **renameDuplicates?**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:38](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L38)

Whether later duplicate enum members are renamed (the tool config's `renameDuplicateIdentifiers`).

***

### skipDuplicates?

> `optional` **skipDuplicates?**: `boolean`

Defined in: [components/cards/PreviewCard.tsx:34](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/PreviewCard.tsx#L34)

Whether Generate leaves files with duplicate identifiers unwritten (the tool config's `skipDuplicateIdentifiers`).
