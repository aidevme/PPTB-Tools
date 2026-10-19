# Function: buildPageQuery()

> **buildPageQuery**(`query`, `afterId`, `pageSize?`): `string`

Defined in: [services/paging.ts:31](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/services/paging.ts#L31)

The OData query for the page after `afterId` (or the first page). Exported for tests.

## Parameters

### query

[`PagedQuery`](../interfaces/PagedQuery.md)

### afterId

`string` \| `undefined`

### pageSize?

`number` = `QUERY_PAGE_SIZE`

## Returns

`string`
