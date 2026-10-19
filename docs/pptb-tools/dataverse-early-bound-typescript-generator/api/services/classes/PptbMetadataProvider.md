# Class: PptbMetadataProvider

Defined in: [services/metadataProvider.ts:56](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/metadataProvider.ts#L56)

Loads the Dataverse metadata the generator needs through `window.dataverseAPI`.

## Remarks

Everything is cached on the instance, so the app creates one per connection; [PptbMetadataProvider.reset](#reset)
clears the cache.

## Constructors

### Constructor

> **new PptbMetadataProvider**(): `PptbMetadataProvider`

#### Returns

`PptbMetadataProvider`

## Accessors

### usesMetadataFallback

#### Get Signature

> **get** **usesMetadataFallback**(): `boolean`

Defined in: [services/metadataProvider.ts:146](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/metadataProvider.ts#L146)

Whether the schema was rebuilt from table and relationship metadata because the `$metadata` document
is too large for PPTB. Built-in actions/functions and custom process actions are unavailable then.

##### Returns

`boolean`

## Methods

### getCsdl()

> **getCsdl**(): `Promise`\<`string`\>

Defined in: [services/metadataProvider.ts:107](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/metadataProvider.ts#L107)

Raw `$metadata` document, fetched once per connection.

#### Returns

`Promise`\<`string`\>

***

### getCustomApis()

> **getCustomApis**(): `Promise`\<`CustomApiRecord`[]\>

Defined in: [services/metadataProvider.ts:203](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/metadataProvider.ts#L203)

Custom API records, fetched once per connection. A failed fetch isn't cached, so the next call retries.

#### Returns

`Promise`\<`CustomApiRecord`[]\>

***

### getEntities()

> **getEntities**(`logicalNames`, `onProgress?`): `Promise`\<[`EntityMetadataInput`](../../core/interfaces/EntityMetadataInput.md)[]\>

Defined in: [services/metadataProvider.ts:275](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/metadataProvider.ts#L275)

Fetch several entities with limited concurrency, reporting progress per finished entity.

#### Parameters

##### logicalNames

readonly `string`[]

##### onProgress?

(`completed`, `total`, `logicalName`) => `void`

#### Returns

`Promise`\<[`EntityMetadataInput`](../../core/interfaces/EntityMetadataInput.md)[]\>

***

### getEntity()

> **getEntity**(`logicalName`): `Promise`\<[`EntityMetadataInput`](../../core/interfaces/EntityMetadataInput.md)\>

Defined in: [services/metadataProvider.ts:262](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/metadataProvider.ts#L262)

Entity + attributes + option sets for one table (cached).

#### Parameters

##### logicalName

`string`

#### Returns

`Promise`\<[`EntityMetadataInput`](../../core/interfaces/EntityMetadataInput.md)\>

***

### getSchema()

> **getSchema**(): `Promise`\<[`EdmxSchema`](../../core/interfaces/EdmxSchema.md)\>

Defined in: [services/metadataProvider.ts:123](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/metadataProvider.ts#L123)

Parsed CSDL, parsed once per connection. When the CSDL is too large for PPTB, a schema rebuilt from
the table list instead (see [usesMetadataFallback](#usesmetadatafallback)).

#### Returns

`Promise`\<[`EdmxSchema`](../../core/interfaces/EdmxSchema.md)\>

***

### getSchemaForSelection()

> **getSchemaForSelection**(`actions`, `functions`): `Promise`\<[`EdmxSchema`](../../core/interfaces/EdmxSchema.md)\>

Defined in: [services/metadataProvider.ts:222](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/metadataProvider.ts#L222)

The CSDL schema plus definitions for any selected custom API that `$metadata` does not contain
(private custom APIs, or ones created after the environment's metadata cache was built). Those are
built from the `customapi` record and its request parameters.

Throws when the custom API records can't be read, rather than generating without the selected
operations. A selected name that isn't a custom API in the environment (for example one deleted since
it was selected) is skipped with a console warning.

#### Parameters

##### actions

readonly `string`[]

##### functions

readonly `string`[]

#### Returns

`Promise`\<[`EdmxSchema`](../../core/interfaces/EdmxSchema.md)\>

***

### listEntities()

> **listEntities**(): `Promise`\<[`EntitySummary`](../../types/interfaces/EntitySummary.md)[]\>

Defined in: [services/metadataProvider.ts:68](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/metadataProvider.ts#L68)

All tables, sorted by display name.

#### Returns

`Promise`\<[`EntitySummary`](../../types/interfaces/EntitySummary.md)[]\>

***

### listOperations()

> **listOperations**(): `Promise`\<[`OperationSummary`](../../types/interfaces/OperationSummary.md)[]\>

Defined in: [services/metadataProvider.ts:151](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/metadataProvider.ts#L151)

Actions and functions from the CSDL, for the Select step.

#### Returns

`Promise`\<[`OperationSummary`](../../types/interfaces/OperationSummary.md)[]\>

***

### reset()

> **reset**(): `void`

Defined in: [services/metadataProvider.ts:283](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/metadataProvider.ts#L283)

Drop all cached data (e.g. after the user asks for a refresh).

#### Returns

`void`
