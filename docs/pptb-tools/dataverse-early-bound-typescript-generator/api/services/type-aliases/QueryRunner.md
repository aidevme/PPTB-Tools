# Type Alias: QueryRunner

> **QueryRunner** = (`odataQuery`) => `Promise`\<\{ `value`: `Record`\<`string`, `unknown`\>[]; \}\>

Defined in: [services/paging.ts:16](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/paging.ts#L16)

Runs one OData query and returns its rows, e.g. `dataverseAPI.queryData`.

## Parameters

### odataQuery

`string`

## Returns

`Promise`\<\{ `value`: `Record`\<`string`, `unknown`\>[]; \}\>
