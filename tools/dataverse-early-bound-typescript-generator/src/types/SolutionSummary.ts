/** A Dataverse solution, used to filter the table list. */
export interface SolutionSummary {
    id: string;
    uniqueName: string;
    friendlyName: string;
    version: string;
    isManaged: boolean;
}
