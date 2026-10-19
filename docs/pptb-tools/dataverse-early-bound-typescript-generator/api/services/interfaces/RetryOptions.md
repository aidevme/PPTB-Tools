# Interface: RetryOptions

Defined in: [services/errors.ts:144](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/errors.ts#L144)

Options for [withRetry](../functions/withRetry.md); every one is optional.

## Properties

### attempts?

> `optional` **attempts?**: `number`

Defined in: [services/errors.ts:146](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/errors.ts#L146)

Total attempts, including the first. Default 3.

***

### baseDelayMs?

> `optional` **baseDelayMs?**: `number`

Defined in: [services/errors.ts:148](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/errors.ts#L148)

Delay before the first retry in ms; doubles each retry. Default 500.

***

### shouldRetry?

> `optional` **shouldRetry?**: (`error`) => `boolean`

Defined in: [services/errors.ts:150](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/errors.ts#L150)

Which errors to retry. Default: [isTransientError](../functions/isTransientError.md).

#### Parameters

##### error

`unknown`

#### Returns

`boolean`

***

### sleep?

> `optional` **sleep?**: (`ms`) => `Promise`\<`void`\>

Defined in: [services/errors.ts:152](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/errors.ts#L152)

Waits between attempts; a parameter so tests don't sleep.

#### Parameters

##### ms

`number`

#### Returns

`Promise`\<`void`\>
