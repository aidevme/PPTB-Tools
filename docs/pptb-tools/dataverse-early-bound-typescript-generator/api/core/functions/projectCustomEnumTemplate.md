# Function: projectCustomEnumTemplate()

> **projectCustomEnumTemplate**(`config`): `boolean` \| `undefined`

Defined in: [core/config.ts:162](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/config.ts#L162)

The project's custom enum template choice.

## Parameters

### config

[`DataverseGenConfig`](../interfaces/DataverseGenConfig.md)

The project's `.dataverse-gen.json` content.

## Returns

`boolean` \| `undefined`

`true` or `false` when the file sets it, or `undefined` when it doesn't (or the value isn't a boolean), so
the default applies.
