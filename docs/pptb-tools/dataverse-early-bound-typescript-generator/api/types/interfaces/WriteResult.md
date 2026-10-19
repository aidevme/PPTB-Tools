# Interface: WriteResult

Defined in: [types/WritePlan.ts:54](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L54)

What a Generate run wrote.

## Properties

### skipped

> **skipped**: `number`

Defined in: [types/WritePlan.ts:58](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L58)

Planned files that weren't written: unchanged files, orphans, and duplicate-identifier files when they're skipped.

***

### written

> **written**: `number`

Defined in: [types/WritePlan.ts:56](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L56)

Files created or overwritten.
