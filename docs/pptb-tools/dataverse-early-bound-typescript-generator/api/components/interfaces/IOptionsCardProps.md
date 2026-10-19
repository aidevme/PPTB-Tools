# Interface: IOptionsCardProps

Defined in: [components/cards/OptionsCard.tsx:9](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/OptionsCard.tsx#L9)

Props for [OptionsCard](../functions/OptionsCard.md).

## Properties

### config

> **config**: [`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)

Defined in: [components/cards/OptionsCard.tsx:13](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/OptionsCard.tsx#L13)

The project's `.dataverse-gen.json` settings the inputs show; unset options show dataverse-gen's defaults.

***

### disabled

> **disabled**: `boolean`

Defined in: [components/cards/OptionsCard.tsx:15](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/OptionsCard.tsx#L15)

Disables the output folder input and the switches (no connection or project yet, or work in progress).

***

### onChange

> **onChange**: (`update`) => `void`

Defined in: [components/cards/OptionsCard.tsx:20](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/OptionsCard.tsx#L20)

Called on every edit with only the changed settings: `output` (with `outputRoot` merged into the existing
`output`), `generateEntityTypes`, `generateFormContext` or `generateIndex`.

#### Parameters

##### update

`Partial`\<[`DataverseGenConfig`](../../core/interfaces/DataverseGenConfig.md)\>

#### Returns

`void`

***

### step

> **step**: [`StepState`](StepState.md)

Defined in: [components/cards/OptionsCard.tsx:11](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/OptionsCard.tsx#L11)

The card's step in the workflow: number, title and completion badge.
