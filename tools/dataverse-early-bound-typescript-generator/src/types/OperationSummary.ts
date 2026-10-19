/** An OData action or function, as listed in the Select step. */
export interface OperationSummary {
    /** The message name, for example `WinOpportunity`; the name a project's config lists. */
    name: string;
    /** Whether it's an OData action (changes data) or a function (reads data). */
    kind: 'action' | 'function';
    /** Bound to a table (called on a record or collection) rather than unbound. */
    isBound: boolean;
    /** Logical name of the entity a bound operation binds to (first parameter's type), if any. */
    boundTo?: string;
    /**
     * The parameters in `$metadata`, including a bound operation's binding parameter; `0` when the operation isn't
     * in `$metadata` (see {@link OperationSummary.inMetadata}).
     */
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
