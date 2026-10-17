/**
 * Typed reads of Web API row columns, in place of `row.column as string` casts: PPTB returns rows as loosely typed
 * records, so each column's type is checked here instead of asserted at every call site.
 */

/** The column's value when it's a string; `undefined` when it's missing, `null` or another type. */
export function textOf(row: object, column: string): string | undefined {
    const value = (row as Record<string, unknown>)[column];
    return typeof value === 'string' ? value : undefined;
}
