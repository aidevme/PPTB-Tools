/** A Dataverse `solution` record, for the "Solutions & Publishers" filters. */
export interface SolutionInfo {
    solutionid: string;
    friendlyname: string;
    uniquename: string;
    version: string;
    description: string;
    /** True for the environment's own auto-created "Default Solution" (`uniquename === "Default"`). */
    isDefaultSolution: boolean;
}
