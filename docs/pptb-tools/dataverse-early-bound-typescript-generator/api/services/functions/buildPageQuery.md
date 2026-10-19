# Function: buildPageQuery()

> **buildPageQuery**(`query`, `afterId`, `pageSize?`): `string`

Defined in: [services/paging.ts:31](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/paging.ts#L31)

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
