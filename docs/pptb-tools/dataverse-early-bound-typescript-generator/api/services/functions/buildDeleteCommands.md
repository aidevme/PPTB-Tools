# Function: buildDeleteCommands()

> **buildDeleteCommands**(`paths`): `string`[]

Defined in: [services/fileSink.ts:45](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/fileSink.ts#L45)

Shell commands that delete `paths`, in batches: PowerShell's `Remove-Item -LiteralPath` for Windows paths (no
wildcard expansion), `rm -f --` otherwise. Every path is single-quoted, so spaces, `$` and backticks are literal.

## Parameters

### paths

`string`[]

## Returns

`string`[]
