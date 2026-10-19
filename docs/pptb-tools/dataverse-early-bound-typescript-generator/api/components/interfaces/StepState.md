# Interface: StepState

Defined in: [components/shared/workflowSteps.ts:7](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/workflowSteps.ts#L7)

What a card's step header and the workflow progress bar show for one step.

## Properties

### active

> **active**: `boolean`

Defined in: [components/shared/workflowSteps.ts:17](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/workflowSteps.ts#L17)

The first step that isn't done yet: highlighted as the one to work on.

***

### complete

> **complete**: `boolean`

Defined in: [components/shared/workflowSteps.ts:15](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/workflowSteps.ts#L15)

The step is done: shown as a check mark.

***

### key

> **key**: `StepKey`

Defined in: [components/shared/workflowSteps.ts:9](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/workflowSteps.ts#L9)

Which step this is.

***

### number

> **number**: `number`

Defined in: [components/shared/workflowSteps.ts:11](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/workflowSteps.ts#L11)

The step's 1-based position, shown in its indicator until the step is done.

***

### status

> **status**: `string`

Defined in: [components/shared/workflowSteps.ts:19](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/workflowSteps.ts#L19)

Short status for the step's badge, e.g. "Ready" or "12 selected".

***

### statusColor

> **statusColor**: `NonNullable`\<`"warning"` \| `"subtle"` \| `"brand"` \| `"danger"` \| `"important"` \| `"informative"` \| `"severe"` \| `"success"` \| `undefined`\>

Defined in: [components/shared/workflowSteps.ts:24](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/workflowSteps.ts#L24)

The status badge's color: `success` when done, `informative` when not started, and `warning` (out of date) or
`brand` (files to write) for the preview step.

***

### title

> **title**: `string`

Defined in: [components/shared/workflowSteps.ts:13](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/components/shared/workflowSteps.ts#L13)

The step's name, shown in its card header and the progress bar, for example "Preview and generate".
