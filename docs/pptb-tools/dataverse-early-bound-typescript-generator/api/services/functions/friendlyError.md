# Function: friendlyError()

> **friendlyError**(`error`): `string`

Defined in: [services/errors.ts:78](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/errors.ts#L78)

A short, actionable message for users, without stack traces or raw payloads. Known HTTP statuses and Dataverse
codes use the guide's messages; file access and invalid JSON get their own; anything else falls back to the
error's own message, since the tool's own errors are already written for users.

## Parameters

### error

`unknown`

## Returns

`string`
