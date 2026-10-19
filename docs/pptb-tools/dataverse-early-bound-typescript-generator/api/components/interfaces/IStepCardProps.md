# Interface: IStepCardProps

Defined in: [components/shared/StepCard.tsx:21](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/shared/StepCard.tsx#L21)

Props for [StepCard](../functions/StepCard.md).

## Properties

### children

> **children**: `ReactNode`

Defined in: [components/shared/StepCard.tsx:27](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/shared/StepCard.tsx#L27)

The card's body, rendered below the header.

***

### description

> **description**: `string` \| `ReactElement`\<`any`, `string` \| `JSXElementConstructor`\<`any`\>\>

Defined in: [components/shared/StepCard.tsx:25](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/shared/StepCard.tsx#L25)

Explanation under the title: a string (shown as small text) or an element.

***

### step

> **step**: [`StepState`](StepState.md)

Defined in: [components/shared/StepCard.tsx:23](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/shared/StepCard.tsx#L23)

The step this card is for: its number, title, status badge, completion and whether it's the active step.
