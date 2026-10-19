# Interface: PagedQuery

Defined in: [services/paging.ts:19](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/paging.ts#L19)

A query [queryAllPages](../functions/queryAllPages.md) runs page by page, continuing after the last `idField` value.

## Properties

### entitySet

> **entitySet**: `string`

Defined in: [services/paging.ts:21](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/paging.ts#L21)

Entity set name, e.g. `customapis`.

***

### filter?

> `optional` **filter?**: `string`

Defined in: [services/paging.ts:27](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/paging.ts#L27)

Optional `$filter` expression, combined with the paging condition.

***

### idField

> **idField**: `string`

Defined in: [services/paging.ts:25](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/paging.ts#L25)

Unique key column the pages are ordered and continued by, e.g. `customapiid`. A GUID or number column.

***

### select

> **select**: `string`[]

Defined in: [services/paging.ts:23](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/paging.ts#L23)

Columns to return; `idField` is added when missing.
