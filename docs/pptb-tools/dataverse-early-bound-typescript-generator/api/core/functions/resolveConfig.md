# Function: resolveConfig()

> **resolveConfig**(`config`): [`ResolvedConfig`](../interfaces/ResolvedConfig.md)

Defined in: [core/config.ts:87](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/config.ts#L87)

Deep-merge user config over the defaults, the way dataverse-gen's `_merge(defaultOptions, options)`
does. `referencedTypes` entries are merged per key so a partial override keeps the other defaults.

## Parameters

### config

[`DataverseGenConfig`](../interfaces/DataverseGenConfig.md) \| `undefined`

## Returns

[`ResolvedConfig`](../interfaces/ResolvedConfig.md)
