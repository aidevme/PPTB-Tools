# Function: queryAllPages()

> **queryAllPages**(`run`, `query`, `__namedParameters?`): `Promise`\<`Record`\<`string`, `unknown`\>[]\>

Defined in: [services/paging.ts:43](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/paging.ts#L43)

Every row of `query`, read page by page in `idField` order. Stops after a page shorter than `pageSize`. Throws if
the key doesn't advance between pages or more than `maxPages` pages would be needed, rather than returning a
silently incomplete list.

## Parameters

### run

[`QueryRunner`](../type-aliases/QueryRunner.md)

### query

[`PagedQuery`](../interfaces/PagedQuery.md)

### \_\_namedParameters?

#### maxPages?

`number` = `QUERY_MAX_PAGES`

#### pageSize?

`number` = `QUERY_PAGE_SIZE`

## Returns

`Promise`\<`Record`\<`string`, `unknown`\>[]\>
