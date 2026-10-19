# Function: withProjectCustomEnumTemplate()

> **withProjectCustomEnumTemplate**(`config`, `value`): [`DataverseGenConfig`](../interfaces/DataverseGenConfig.md)

Defined in: [core/config.ts:173](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/config.ts#L173)

A copy of the config with the project's custom enum template choice set; every other key, including other keys of
the tool's settings object, is kept.

## Parameters

### config

[`DataverseGenConfig`](../interfaces/DataverseGenConfig.md)

The project's `.dataverse-gen.json` content.

### value

`boolean`

The choice to store.

## Returns

[`DataverseGenConfig`](../interfaces/DataverseGenConfig.md)

The updated config; `config` itself isn't changed.
