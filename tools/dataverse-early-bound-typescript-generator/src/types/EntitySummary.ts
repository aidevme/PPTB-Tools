/** A Dataverse table as listed in the Select step. */
export interface EntitySummary {
    logicalName: string;
    schemaName: string;
    displayName: string;
    /** The table's description in the user's language; empty when it has none. */
    description: string;
    entitySetName?: string;
    /** `MetadataId`, used to match `solutioncomponent` rows for the solution filter. */
    metadataId: string;
    isCustom: boolean;
    isManaged: boolean;
}
