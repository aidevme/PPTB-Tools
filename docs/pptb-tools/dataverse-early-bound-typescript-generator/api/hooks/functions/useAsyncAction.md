# Function: useAsyncAction()

> **useAsyncAction**(`setError`): `object`

Defined in: [hooks/useAsyncAction.ts:10](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/hooks/useAsyncAction.ts#L10)

An async action a dialog or panel runs from a button (save, open, delete): `busy` while it runs, the error
cleared when it starts and set when it fails. The caller owns the error state, so several actions can share one
error message. Errors are logged and made friendly by `reportError` without a notification, since the caller
shows them in place.

## Parameters

### setError

(`message`) => `void`

## Returns

### busy

> **busy**: `boolean`

### run

> **run**: \<`T`\>(`operation`, `action`) => `Promise`\<`T` \| `undefined`\>

Runs `action`; resolves to its result, or `undefined` when it failed (the error is then shown).

#### Type Parameters

##### T

`T`

#### Parameters

##### operation

`string`

##### action

() => `Promise`\<`T`\>

#### Returns

`Promise`\<`T` \| `undefined`\>
