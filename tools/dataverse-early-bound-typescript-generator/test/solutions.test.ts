/**
 * The solution filter's Dataverse reads: the solution list, a solution's tables, and which components (custom
 * APIs, process actions) belong to it, queried in chunks.
 */
import { afterEach, describe, expect, it, vi } from 'vitest';
import { getSolutionEntityIds, getSolutionMemberIds, listSolutions } from '../src/services/solutions';

function installDataverseStub(api: Record<string, unknown>) {
    (window as unknown as { dataverseAPI: unknown }).dataverseAPI = api;
}

afterEach(() => {
    delete (window as unknown as { dataverseAPI?: unknown }).dataverseAPI;
});

describe('listSolutions', () => {
    it('lists visible unmanaged solutions by friendly name, falling back to the unique name', async () => {
        installDataverseStub({
            getSolutions: async () => ({
                value: [
                    { solutionid: 's1', uniquename: 'zeta', friendlyname: 'Zeta', version: '1.0', ismanaged: false, isvisible: true },
                    { solutionid: 's2', uniquename: 'managed', friendlyname: 'Managed', version: '2.0', ismanaged: true, isvisible: true },
                    { solutionid: 's3', uniquename: 'hidden', friendlyname: 'Hidden', version: '3.0', ismanaged: false, isvisible: false },
                    { solutionid: 's4', uniquename: 'alpha', friendlyname: null, version: null, ismanaged: false },
                ],
            }),
        });
        expect(await listSolutions()).toEqual([
            { id: 's4', uniqueName: 'alpha', friendlyName: 'alpha', version: '', isManaged: false },
            { id: 's1', uniqueName: 'zeta', friendlyName: 'Zeta', version: '1.0', isManaged: false },
        ]);
    });

    it('fails outside PPTB', async () => {
        await expect(listSolutions()).rejects.toThrow('The PPTB Dataverse API is not available');
    });
});

describe('getSolutionEntityIds', () => {
    it("returns the solution's table components, lower-cased", async () => {
        const queryData = vi.fn(async () => ({ value: [{ objectid: 'AAA-1' }, { objectid: 'bbb-2' }] }));
        installDataverseStub({ queryData });
        expect([...(await getSolutionEntityIds('sol-1'))]).toEqual(['aaa-1', 'bbb-2']);
        expect(queryData).toHaveBeenCalledWith('solutioncomponents?$select=objectid&$filter=_solutionid_value eq sol-1 and componenttype eq 1');
    });
});

describe('getSolutionMemberIds', () => {
    it('queries the ids in chunks of 40 and returns the members, lower-cased', async () => {
        const ids = Array.from({ length: 45 }, (_, i) => `ID-${i}`);
        const queryData = vi.fn(async (query: string) => ({ value: query.includes('objectid eq id-44') ? [{ objectid: 'ID-44' }] : [{ objectid: 'ID-0' }] }));
        installDataverseStub({ queryData });
        const members = await getSolutionMemberIds('sol-1', [...ids, 'id-0']);
        expect(queryData).toHaveBeenCalledTimes(2);
        expect(queryData.mock.calls[0][0]).toContain('_solutionid_value eq sol-1 and (objectid eq id-0 or objectid eq id-1');
        expect([...members].sort()).toEqual(['id-0', 'id-44']);
    });

    it('makes no request without ids', async () => {
        const queryData = vi.fn();
        installDataverseStub({ queryData });
        expect((await getSolutionMemberIds('sol-1', [])).size).toBe(0);
        expect(queryData).not.toHaveBeenCalled();
    });
});
