# Function: stepElementId()

> **stepElementId**(`key`): `string`

Defined in: [components/shared/workflowSteps.ts:46](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/shared/workflowSteps.ts#L46)

Element id of a step's card, used by the progress bar to scroll to it.

## Parameters

### key

`StepKey`

The step.

## Returns

`string`

`workflow-step-` followed by `key`.
