# Interface: Progress

Defined in: [types/index.ts:7](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/index.ts#L7)

Progress of a multi-step background task, shown in the UI.

## Properties

### completed

> **completed**: `number`

Defined in: [types/index.ts:11](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/index.ts#L11)

Steps finished so far.

***

### message

> **message**: `string`

Defined in: [types/index.ts:9](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/index.ts#L9)

Short description of what is happening right now.

***

### total

> **total**: `number`

Defined in: [types/index.ts:13](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/index.ts#L13)

Steps in all; `0` shows an indeterminate progress bar.
