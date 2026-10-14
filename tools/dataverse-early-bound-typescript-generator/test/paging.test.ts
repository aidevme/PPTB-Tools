/**
 * Keyset paging over `dataverseAPI.queryData`: every row of a query, one fixed-size page at a time, continuing
 * after the last key, without relying on `@odata.nextLink`.
 */
import { describe, expect, it, vi } from 'vitest';
import { QUERY_PAGE_SIZE, buildPageQuery, queryAllPages, type PagedQuery } from '../src/services/paging';

const CUSTOM_APIS: PagedQuery = { entitySet: 'customapis', select: ['uniquename'], idField: 'customapiid' };

/** A fake `queryData` over `ids`, honouring `gt`, `$orderby` (ascending by string) and `$top` like Dataverse. */
function fakeRunner(ids: string[]) {
    const sorted = [...ids].sort();
    return vi.fn(async (query: string) => {
        const after = /customapiid gt ([^&)\s]+)/.exec(query)?.[1];
        const top = Number(/\$top=(\d+)/.exec(query)?.[1]);
        const rows = sorted.filter((id) => after === undefined || id > after).slice(0, top);
        return { value: rows.map((id) => ({ customapiid: id, uniquename: `api_${id}` })) };
    });
}

const ids = (count: number) => Array.from({ length: count }, (_, i) => `id${String(i).padStart(5, '0')}`);

describe('buildPageQuery', () => {
    it('selects the key, orders by it and asks for one page', () => {
        expect(buildPageQuery(CUSTOM_APIS, undefined)).toBe(
            `customapis?$select=uniquename,customapiid&$orderby=customapiid asc&$top=${QUERY_PAGE_SIZE}`,
        );
    });

    it('continues after the last key, keeping the caller filter', () => {
        const query: PagedQuery = { entitySet: 'workflows', select: ['workflowid', 'name'], idField: 'workflowid', filter: 'category eq 3 and type eq 1' };
        expect(buildPageQuery(query, 'abc', 10)).toBe(
            'workflows?$select=workflowid,name&$filter=(category eq 3 and type eq 1) and workflowid gt abc&$orderby=workflowid asc&$top=10',
        );
    });
});

describe('queryAllPages', () => {
    it('reads a single short page with one request', async () => {
        const run = fakeRunner(ids(3));
        expect(await queryAllPages(run, CUSTOM_APIS, { pageSize: 10 })).toHaveLength(3);
        expect(run).toHaveBeenCalledTimes(1);
    });

    it('combines several pages without gaps or duplicates', async () => {
        const all = ids(25);
        const run = fakeRunner(all);
        const rows = await queryAllPages(run, CUSTOM_APIS, { pageSize: 10 });
        expect(rows.map((r) => r.customapiid)).toEqual(all);
        // 10 + 10 + 5: the short third page ends it.
        expect(run).toHaveBeenCalledTimes(3);
        expect(run.mock.calls[1][0]).toContain('customapiid gt id00009');
    });

    it('asks for one more (empty) page when the last page is exactly full', async () => {
        const run = fakeRunner(ids(20));
        expect(await queryAllPages(run, CUSTOM_APIS, { pageSize: 10 })).toHaveLength(20);
        expect(run).toHaveBeenCalledTimes(3);
    });

    it('returns nothing for an empty result', async () => {
        expect(await queryAllPages(fakeRunner([]), CUSTOM_APIS, { pageSize: 10 })).toEqual([]);
    });

    it('stops with an error when the key does not advance', async () => {
        const stuck = vi.fn(async () => ({ value: Array.from({ length: 2 }, () => ({ customapiid: 'same' })) }));
        await expect(queryAllPages(stuck, CUSTOM_APIS, { pageSize: 2 })).rejects.toThrow(/didn't advance/);
    });

    it('stops with an error after the page limit instead of returning a partial list', async () => {
        const run = fakeRunner(ids(50));
        await expect(queryAllPages(run, CUSTOM_APIS, { pageSize: 10, maxPages: 3 })).rejects.toThrow(/stopped after 3 pages/);
        expect(run).toHaveBeenCalledTimes(3);
    });
});
