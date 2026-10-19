# Interface: ISelectionCardProps

Defined in: [components/cards/SelectionCard.tsx:56](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L56)

Props for [SelectionCard](../functions/SelectionCard.md).

## Properties

### disabled

> **disabled**: `boolean`

Defined in: [components/cards/SelectionCard.tsx:75](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L75)

Disables the row checkboxes and Clear (no connection or project yet, or work in progress); an empty list
then asks the user to connect.

***

### entities

> **entities**: [`EntitySummary`](../../types/interfaces/EntitySummary.md)[]

Defined in: [components/cards/SelectionCard.tsx:60](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L60)

The environment's tables, listed on the Tables tab.

***

### loading

> **loading**: [`ISelectionLoading`](ISelectionLoading.md)

Defined in: [components/cards/SelectionCard.tsx:66](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L66)

Which lists are still loading.

***

### missing

> **missing**: `Record`\<[`SelectionKind`](../type-aliases/SelectionKind.md), `string`[]\>

Defined in: [components/cards/SelectionCard.tsx:70](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L70)

Names in the config that the connected environment does not have.

***

### needsProject?

> `optional` **needsProject?**: `boolean`

Defined in: [components/cards/SelectionCard.tsx:81](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L81)

No project open yet: the lists stay empty and the tabs, search, solution filter, switches and Clear are
disabled until one is created or opened.

#### Default Value

```ts
false
```

***

### onClear

> **onClear**: (`kind`) => `void`

Defined in: [components/cards/SelectionCard.tsx:85](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L85)

Called with the current tab when Clear is clicked, to empty that tab's selection.

#### Parameters

##### kind

[`SelectionKind`](../type-aliases/SelectionKind.md)

#### Returns

`void`

***

### onEnsureOperations

> **onEnsureOperations**: () => `void`

Defined in: [components/cards/SelectionCard.tsx:89](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L89)

Called when the actions/functions tabs are opened, so the CSDL is only fetched when needed.

#### Returns

`void`

***

### onSolutionChange

> **onSolutionChange**: (`solutionId`) => `void`

Defined in: [components/cards/SelectionCard.tsx:87](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L87)

Called with the chosen solution's id when the solution dropdown changes, or `null` when it's cleared.

#### Parameters

##### solutionId

`string` \| `null`

#### Returns

`void`

***

### onToggle

> **onToggle**: (`kind`, `name`, `checked`) => `void`

Defined in: [components/cards/SelectionCard.tsx:83](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L83)

Called when a row's checkbox changes, with the current tab, the row's name and whether it's now checked.

#### Parameters

##### kind

[`SelectionKind`](../type-aliases/SelectionKind.md)

##### name

`string`

##### checked

`boolean`

#### Returns

`void`

***

### operations

> **operations**: [`OperationSummary`](../../types/interfaces/OperationSummary.md)[] \| `null`

Defined in: [components/cards/SelectionCard.tsx:62](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L62)

The environment's actions and functions, or `null` until they're loaded (see `onEnsureOperations`).

***

### rowLimit?

> `optional` **rowLimit?**: `number`

Defined in: [components/cards/SelectionCard.tsx:91](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L91)

The most rows each table lists (the General setting); defaults to 500.

***

### selected

> **selected**: `Record`\<[`SelectionKind`](../type-aliases/SelectionKind.md), `string`[]\>

Defined in: [components/cards/SelectionCard.tsx:68](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L68)

The selected names per tab (logical names for tables), as stored in the config.

***

### solutionFilter

> **solutionFilter**: [`ISelectionSolutionFilter`](ISelectionSolutionFilter.md)

Defined in: [components/cards/SelectionCard.tsx:64](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L64)

The solution dropdown's options and what the chosen solution contains.

***

### step

> **step**: [`StepState`](StepState.md)

Defined in: [components/cards/SelectionCard.tsx:58](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/cards/SelectionCard.tsx#L58)

The card's step in the workflow: number, title and completion badge.
