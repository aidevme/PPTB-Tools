# Function: withRetries()

> **withRetries**\<`T`\>(`api`, `options?`): `T`

Defined in: [services/errors.ts:122](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/errors.ts#L122)

A view of `api` whose methods run through [withRetry](withRetry.md), so every call retries transient failures. Non-function
properties pass through unchanged. One proxy is cached per underlying object.

The proxy wraps an empty object and reads from `api`, rather than wrapping `api` itself: PPTB exposes its APIs
through Electron's contextBridge, which freezes them, and a proxy over a frozen object must return each
property's actual value, so returning a wrapped method from it throws on every call.

## Type Parameters

### T

`T` *extends* `object`

## Parameters

### api

`T`

### options?

[`RetryOptions`](../interfaces/RetryOptions.md)

## Returns

`T`
