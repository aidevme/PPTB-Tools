/**
 * The kind of Dataverse table, as Power Apps shows it. Dataverse's `TableType` holds Standard, Virtual or Elastic;
 * activity tables report `Standard` there and are identified by `IsActivity` instead.
 */
export type TableType = 'Standard' | 'Activity' | 'Virtual' | 'Elastic';

/** A Dataverse table as listed in the Select step. */
export interface EntitySummary {
    /** The table's logical name, for example `account`; the name a project's config lists. */
    logicalName: string;
    /** The table's schema name, for example `Account`; the logical name when Dataverse returns none. */
    schemaName: string;
    /** The table's display name in the user's language; the logical name when it has none. */
    displayName: string;
    /** The table's description in the user's language; empty when it has none. */
    description: string;
    /** The Web API collection name, for example `accounts`; `undefined` when the metadata doesn't include one. */
    entitySetName?: string;
    /** `MetadataId`, used to match `solutioncomponent` rows for the solution filter. */
    metadataId: string;
    /** Created by a customizer rather than shipped with Dataverse. */
    isCustom: boolean;
    /** Part of a managed solution. */
    isManaged: boolean;
    /** The kind of table, as Power Apps shows it. */
    tableType: TableType;
}
