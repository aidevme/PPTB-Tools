# Variable: NOTIFICATION\_TYPES

> `const` **NOTIFICATION\_TYPES**: `object`

Defined in: [services/notifications.ts:16](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/notifications.ts#L16)

The four notification presets: PPTB's type, a default title, and how long it stays up in milliseconds
(`0` = until the user dismisses it). Warnings and errors stay up so they aren't missed.

## Type Declaration

### error

> `readonly` **error**: `object`

Critical failure.

#### error.duration

> `readonly` **duration**: `0` = `0`

#### error.title

> `readonly` **title**: `"Error"` = `'Error'`

#### error.type

> `readonly` **type**: `"error"` = `'error'`

### info

> `readonly` **info**: `object`

Informational message.

#### info.duration

> `readonly` **duration**: `5000` = `5000`

#### info.title

> `readonly` **title**: `"Info"` = `'Info'`

#### info.type

> `readonly` **type**: `"info"` = `'info'`

### success

> `readonly` **success**: `object`

Operation completed successfully.

#### success.duration

> `readonly` **duration**: `3000` = `3000`

#### success.title

> `readonly` **title**: `"Success"` = `'Success'`

#### success.type

> `readonly` **type**: `"success"` = `'success'`

### warning

> `readonly` **warning**: `object`

Non-critical issue.

#### warning.duration

> `readonly` **duration**: `0` = `0`

#### warning.title

> `readonly` **title**: `"Warning"` = `'Warning'`

#### warning.type

> `readonly` **type**: `"warning"` = `'warning'`
