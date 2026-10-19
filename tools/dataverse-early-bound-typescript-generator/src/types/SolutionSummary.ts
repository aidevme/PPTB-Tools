/** A Dataverse solution, used to filter the table list. */
export interface SolutionSummary {
    /** The `solutionid`. */
    id: string;
    /** The solution's unique name, for example `ContosoCore`. */
    uniqueName: string;
    /** The display name; the unique name when it has none. */
    friendlyName: string;
    /** The version number, for example `1.0.0.3`. */
    version: string;
    /** Whether the solution is managed. */
    isManaged: boolean;
}
