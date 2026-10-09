/**
 * Solution list and solution → table membership, for the Select step's solution filter.
 */
import type { SolutionSummary } from '../types';

const ENTITY_COMPONENT_TYPE = 1;

function api(): typeof window.dataverseAPI {
    if (!window.dataverseAPI) throw new Error('The PPTB Dataverse API is not available (not running inside Power Platform ToolBox?)');
    return window.dataverseAPI;
}

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

/** `MetadataId`s of the tables that are components of a solution. */
export async function getSolutionEntityIds(solutionId: string): Promise<Set<string>> {
    const result = await api().queryData(
        `solutioncomponents?$select=objectid&$filter=_solutionid_value eq ${solutionId} and componenttype eq ${ENTITY_COMPONENT_TYPE}`,
    );
    return new Set(result.value.map((row) => String(row.objectid).toLowerCase()));
}
