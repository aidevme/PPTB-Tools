/**
 * Solution list and solution → table membership, for the Select step's solution filter.
 */
import type { SolutionSummary } from '../types';
import { dataverseApi as api } from './errors';

const ENTITY_COMPONENT_TYPE = 1;

/** Visible unmanaged solutions, sorted by friendly name. */
export async function listSolutions(): Promise<SolutionSummary[]> {
    const result = await api().getSolutions(['solutionid', 'uniquename', 'friendlyname', 'version', 'ismanaged', 'isvisible']);
    return result.value
        .filter((s) => s.isvisible !== false && s.ismanaged !== true)
        .map((s) => ({
            id: s.solutionid as string,
            uniqueName: s.uniquename as string,
            friendlyName: (s.friendlyname as string) || (s.uniquename as string),
            version: (s.version as string) ?? '',
            isManaged: s.ismanaged === true,
        }))
        .sort((a, b) => a.friendlyName.localeCompare(b.friendlyName));
}

/** How many object ids go into one `solutioncomponents` query, to keep the URL short. */
const OBJECT_ID_CHUNK = 40;

/**
 * Which of the given component record ids (custom API ids, process-action workflow ids, …) are part of
 * a solution. Queried in chunks by id rather than listing every component of the solution, which can be
 * tens of thousands of rows for the Default solution.
 */
export async function getSolutionMemberIds(solutionId: string, objectIds: readonly string[]): Promise<Set<string>> {
    const members = new Set<string>();
    const unique = [...new Set(objectIds.map((id) => id.toLowerCase()))];
    for (let i = 0; i < unique.length; i += OBJECT_ID_CHUNK) {
        const chunk = unique.slice(i, i + OBJECT_ID_CHUNK);
        const idFilter = chunk.map((id) => `objectid eq ${id}`).join(' or ');
        const result = await api().queryData(`solutioncomponents?$select=objectid&$filter=_solutionid_value eq ${solutionId} and (${idFilter})`);
        for (const row of result.value) members.add(String(row.objectid).toLowerCase());
    }
    return members;
}

/** `MetadataId`s of the tables that are components of a solution. */
export async function getSolutionEntityIds(solutionId: string): Promise<Set<string>> {
    const result = await api().queryData(
        `solutioncomponents?$select=objectid&$filter=_solutionid_value eq ${solutionId} and componenttype eq ${ENTITY_COMPONENT_TYPE}`,
    );
    return new Set(result.value.map((row) => String(row.objectid).toLowerCase()));
}
