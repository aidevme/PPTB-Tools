# Function: computeWorkflowSteps()

> **computeWorkflowSteps**(`input`): [`StepState`](../interfaces/StepState.md)[]

Defined in: [components/shared/workflowSteps.ts:59](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/components/shared/workflowSteps.ts#L59)

The four workflow steps with their completion, the step to work on next, and a status for each.

- **Project** is done once a project folder is open.
- **Select** is done once anything is selected.
- **Options** is done once a project is open: its options then exist, with defaults if never changed.
- **Preview** is done when an up-to-date preview has nothing left to write.

## Parameters

### input

`WorkflowInput`

Whether a project is open, the selection count and the last preview; see WorkflowInput.

## Returns

[`StepState`](../interfaces/StepState.md)[]

The four steps in order, with exactly one `active` (the first not done), or none when all are done.
