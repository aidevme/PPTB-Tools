# Function: editedEnumTemplate()

> **editedEnumTemplate**(`plan`): [`PlannedFile`](../../types/interfaces/PlannedFile.md) \| `undefined`

Defined in: [services/dataverseGenTemplates.ts:81](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/dataverseGenTemplates.ts#L81)

The project's `enum.ejs` from a write plan when it looks edited: it exists on disk and differs from both
dataverse-gen's template and the custom enum template (line endings ignored, as the write plan compares).

## Parameters

### plan

[`WritePlan`](../../types/interfaces/WritePlan.md) \| `null`

The last preview's write plan, or `null` before the first preview.

## Returns

[`PlannedFile`](../../types/interfaces/PlannedFile.md) \| `undefined`

The planned `enum.ejs` file, with its `absolutePath`, when it looks edited; otherwise `undefined`.

## Remarks

Used to confirm before the custom enum template replaces a copy the user changed (spec 001, FR-012). It
only knows what the last preview read: a plan without templates (Generate templates off) or without an existing
`enum.ejs` gives `undefined`.
