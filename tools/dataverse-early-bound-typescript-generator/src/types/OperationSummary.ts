/** An OData action or function, as listed in the Select step. */
export interface OperationSummary {
    name: string;
    kind: 'action' | 'function';
    isBound: boolean;
    /** Logical name of the entity a bound operation binds to (first parameter's type), if any. */
    boundTo?: string;
    parameterCount: number;
    /** Backed by a `customapi` record in the environment. */
    isCustomApi: boolean;
    /** Backed by a classic custom process action (`workflow` with category 3). */
    isProcessAction: boolean;
    /** Custom API / process action display name, when it has one. */
    displayName?: string;
    /**
     * Id of the solution-aware record behind the operation (`customapiid` or `workflowid`), used for the
     * solution filter. Built-in messages have none and never match a solution.
     */
    componentId?: string;
    /** Custom API marked private (`IsPrivate = Yes`); still callable through the Web API. */
    isPrivate: boolean;
    /**
     * `false` when the operation is not in the `$metadata` document (private custom APIs, or ones the
     * environment's metadata cache does not include yet). Types are then built from the `customapi`
     * record and its request parameters.
     */
    inMetadata: boolean;
}
