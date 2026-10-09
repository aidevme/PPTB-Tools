/** An OData action or function from the CSDL, as listed in the Select step. */
export interface OperationSummary {
    name: string;
    kind: 'action' | 'function';
    isBound: boolean;
    /** Logical name of the entity a bound operation binds to (first parameter's type), if any. */
    boundTo?: string;
    parameterCount: number;
}
