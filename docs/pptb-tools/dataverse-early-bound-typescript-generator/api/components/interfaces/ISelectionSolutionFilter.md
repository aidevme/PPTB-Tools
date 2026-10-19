# Interface: ISelectionSolutionFilter

Defined in: [components/cards/SelectionCard.tsx:34](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L34)

The solution dropdown and what the chosen solution contains.

## Properties

### componentIds

> **componentIds**: `Set`\<`string`\> \| `null`

Defined in: [components/cards/SelectionCard.tsx:42](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L42)

Ids of custom API / process-action records in the chosen solution, or `null` when not filtering.

***

### entityIds

> **entityIds**: `Set`\<`string`\> \| `null`

Defined in: [components/cards/SelectionCard.tsx:40](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L40)

Entity `MetadataId`s in the chosen solution, or `null` when no solution filter is active.

***

### selectedId

> **selectedId**: `string` \| `null`

Defined in: [components/cards/SelectionCard.tsx:38](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L38)

The chosen solution, or `null` for all solutions.

***

### solutions

> **solutions**: [`SolutionSummary`](../../types/interfaces/SolutionSummary.md)[]

Defined in: [components/cards/SelectionCard.tsx:36](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L36)

The solutions the dropdown offers; the dropdown is disabled while it's empty.
