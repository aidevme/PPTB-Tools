# Function: useCustomEnumTemplateConfirmation()

> **useCustomEnumTemplateConfirmation**(`plan`, `generateTemplates`, `save`): `object`

Defined in: [hooks/useCustomEnumTemplateConfirmation.ts:20](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useCustomEnumTemplateConfirmation.ts#L20)

Turns the custom enum template on or off from the Preview card, asking first when that would replace an edited
`enum.ejs` (spec 001, FR-012).

## Parameters

### plan

[`WritePlan`](../../types/interfaces/WritePlan.md) \| `null`

The last preview's write plan, or `null` before the first preview.

### generateTemplates

`boolean`

Whether Generate writes the templates; off, `enum.ejs` isn't written, so nothing is asked.

### save

(`checked`) => `void`

Saves `customEnumTemplate`.

## Returns

`object`

`request(checked)` for the proposal and the switch, the `pendingPath` of the open confirmation (or
`null`), and its `confirm` and `cancel` handlers.

### cancel

> **cancel**: () => `void`

#### Returns

`void`

### confirm

> **confirm**: () => `void`

#### Returns

`void`

### pendingPath

> **pendingPath**: `string` \| `null`

### request

> **request**: (`checked`) => `void`

#### Parameters

##### checked

`boolean`

#### Returns

`void`

## Remarks

Turning it on with Generate templates on, when the last preview found the project's `enum.ejs` edited
([editedEnumTemplate](../../services/functions/editedEnumTemplate.md)), opens a confirmation instead of saving: `pendingPath` is then the file's path, and
`confirm` saves while `cancel` saves nothing. Every other change (turning it off, Generate templates off, no edited
file known) is saved straight away. The Settings panel asks the same question on its own Save.
