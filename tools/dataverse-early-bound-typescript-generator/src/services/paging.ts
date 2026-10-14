/**
 * Reading every row of a Dataverse Web API query through PPTB's `dataverseAPI.queryData`, which returns one page
 * (at most 5,000 rows by default) and is documented as returning only `{ value }`, so `@odata.nextLink` can't be
 * relied on. Instead the rows are read in key order, one fixed-size page at a time, each page continuing after the
 * last key of the previous one (keyset paging). Only `$select`, `$filter`, `$orderby` and `$top` are used, which
 * PPTB documents for `queryData`.
 */

/** Rows per page; Dataverse's default and maximum page size for the Web API. */
export const QUERY_PAGE_SIZE = 5000;

/** Most pages read before giving up, so a misbehaving key can't loop forever (200 pages = 1,000,000 rows). */
export const QUERY_MAX_PAGES = 200;

/** Runs one OData query and returns its rows, e.g. `dataverseAPI.queryData`. */
export type QueryRunner = (odataQuery: string) => Promise<{ value: Record<string, unknown>[] }>;

export interface PagedQuery {
    /** Entity set name, e.g. `customapis`. */
    entitySet: string;
    /** Columns to return; `idField` is added when missing. */
    select: string[];
    /** Unique key column the pages are ordered and continued by, e.g. `customapiid`. A GUID or number column. */
    idField: string;
    /** Optional `$filter` expression, combined with the paging condition. */
    filter?: string;
}

/** The OData query for the page after `afterId` (or the first page). Exported for tests. */
export function buildPageQuery(query: PagedQuery, afterId: string | undefined, pageSize = QUERY_PAGE_SIZE): string {
    const select = query.select.includes(query.idField) ? query.select : [...query.select, query.idField];
    const conditions = [query.filter && `(${query.filter})`, afterId !== undefined && `${query.idField} gt ${afterId}`].filter(Boolean);
    const filter = conditions.length > 0 ? `&$filter=${conditions.join(' and ')}` : '';
    return `${query.entitySet}?$select=${select.join(',')}${filter}&$orderby=${query.idField} asc&$top=${pageSize}`;
}

/**
 * Every row of `query`, read page by page in `idField` order. Stops after a page shorter than `pageSize`. Throws if
 * the key doesn't advance between pages or more than `maxPages` pages would be needed, rather than returning a
 * silently incomplete list.
 */
export async function queryAllPages(
    run: QueryRunner,
    query: PagedQuery,
    { pageSize = QUERY_PAGE_SIZE, maxPages = QUERY_MAX_PAGES }: { pageSize?: number; maxPages?: number } = {},
): Promise<Record<string, unknown>[]> {
    const rows: Record<string, unknown>[] = [];
    let afterId: string | undefined;
    for (let page = 1; page <= maxPages; page++) {
        const { value } = await run(buildPageQuery(query, afterId, pageSize));
        rows.push(...value);
        if (value.length < pageSize) return rows;
        const lastId = value[value.length - 1][query.idField];
        if (lastId === undefined || lastId === null || String(lastId) === afterId) {
            throw new Error(`Paging ${query.entitySet} stopped: the ${query.idField} of the last row didn't advance.`);
        }
        afterId = String(lastId);
    }
    throw new Error(`Paging ${query.entitySet} stopped after ${maxPages} pages of ${pageSize} rows.`);
}
