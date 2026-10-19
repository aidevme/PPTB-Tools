# Interface: IOptionsCardProps

Defined in: [components/cards/OptionsCard.tsx:10](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/OptionsCard.tsx#L10)

Props for [OptionsCard](../functions/OptionsCard.md).

## Properties

### config

> **config**: [`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)

Defined in: [components/cards/OptionsCard.tsx:14](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/OptionsCard.tsx#L14)

The project's `.dataverse-gen.json` settings the inputs show; unset options show dataverse-gen's defaults.

***

### customEnumTemplate

> **customEnumTemplate**: `boolean`

Defined in: [components/cards/OptionsCard.tsx:26](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/OptionsCard.tsx#L26)

Whether the project uses the custom enum template: its `pptbEarlyBoundGenerator.customEnumTemplate`, or the
Settings default when the project has no value.

***

### disabled

> **disabled**: `boolean`

Defined in: [components/cards/OptionsCard.tsx:16](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/OptionsCard.tsx#L16)

Disables the output folder input and the switches (no connection or project yet, or work in progress).

***

### onChange

> **onChange**: (`update`) => `void`

Defined in: [components/cards/OptionsCard.tsx:21](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/OptionsCard.tsx#L21)

Called on every edit with only the changed settings: `output` (with `outputRoot` merged into the existing
`output`), `generateEntityTypes`, `generateFormContext` or `generateIndex`.

#### Parameters

##### update

`Partial`\<[`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)\>

#### Returns

`void`

***

### onCustomEnumTemplateChange

> **onCustomEnumTemplateChange**: (`checked`) => `void`

Defined in: [components/cards/OptionsCard.tsx:31](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/OptionsCard.tsx#L31)

The Custom enum template switch: asks first when turning it on would replace an edited `enum.ejs`, then saves the
project's value (see `useCustomEnumTemplateConfirmation`).

#### Parameters

##### checked

`boolean`

#### Returns

`void`

***

### step

> **step**: [`StepState`](StepState.md)

Defined in: [components/cards/OptionsCard.tsx:12](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/cards/OptionsCard.tsx#L12)

The card's step in the workflow: number, title and completion badge.
