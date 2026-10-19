# Function: reportError()

> **reportError**(`operation`, `error`, `context?`, `options?`): `string`

Defined in: [services/errors.ts:100](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/errors.ts#L100)

Handles a failed operation: logs the full error with the operation, any context and a timestamp; shows a
persistent error notification titled with the operation (best effort); and returns
`"<operation>: <friendly message>"` for the page's error bar. Pass `notify: false` where the error is already
shown in place, such as inside a dialog.

## Parameters

### operation

`string`

### error

`unknown`

### context?

`Record`\<`string`, `unknown`\>

### options?

#### notify?

`boolean`

## Returns

`string`
