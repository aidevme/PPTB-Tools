import { Badge, Tooltip } from '@fluentui/react-components';
import type { EntitySummary, OperationSummary } from '../../../types';
import type { SelectionRow } from '../../tables/SelectionTable';
import { TABLE_TYPE_COLORS } from '../../tables/selectionColumns';

/** The SelectionCard class names the row cells use. */
export type SelectionRowStyles = Record<'mono' | 'muted' | 'stacked' | 'secondary', string>;

/** Filters shared by every Select tab. */
interface RowFilter {
    /** The search text, already trimmed and lowercased; empty matches everything. */
    term: string;
    selectedOnly: boolean;
    /** Names selected on the current tab. */
    selectedSet: ReadonlySet<string>;
}

/** The Tables tab's filters, for {@link buildEntityRows}. */
export interface EntityRowFilter extends RowFilter {
    /** Entity `MetadataId`s in the chosen solution, or `null` when no solution filter is active. */
    solutionEntityIds: Set<string> | null;
}

/** The Actions or Functions tab's filters, for {@link buildOperationRows}. */
export interface OperationRowFilter extends RowFilter {
    /** Which operations the tab lists: actions or functions. */
    kind: 'action' | 'function';
    /** Lists only custom APIs and custom process actions (the Custom only switch). */
    customApisOnly: boolean;
    /** The chosen solution, or `null` for all solutions; while set, only operations in `solutionComponentIds` pass. */
    selectedSolutionId: string | null;
    /** Ids of custom API / process-action records in the chosen solution, or `null` when not filtering. */
    solutionComponentIds: Set<string> | null;
}

/**
 * Returns the Type column text of an action or function.
 *
 * @param o - The action or function to describe.
 * @returns `"Private custom API"`, `"Custom API"`, `"Custom action"` (a custom process action) or `"Built-in"`.
 */
export function operationType(o: OperationSummary): string {
    if (o.isCustomApi) return o.isPrivate ? 'Private custom API' : 'Custom API';
    return o.isProcessAction ? 'Custom action' : 'Built-in';
}

const matcher =
    (term: string) =>
    (...values: Array<string | undefined>) =>
        !term || values.some((v) => v?.toLowerCase().includes(term));

/**
 * The Tables tab rows: entities in the solution filter, selection filter and search, in the given order.
 *
 * @param entities - The environment's tables.
 * @param filter - The solution, Selected only and search filters; the search matches the logical, display and
 * schema names.
 * @param styles - The SelectionCard class names for the monospace and muted cells.
 * @returns One row per matching table, keyed by logical name, with display name, logical name, schema name,
 * description and table type cells.
 */
export function buildEntityRows(entities: EntitySummary[], filter: EntityRowFilter, styles: SelectionRowStyles): SelectionRow[] {
    const matches = matcher(filter.term);
    return entities
        .filter((e) => !filter.solutionEntityIds || filter.solutionEntityIds.has(e.metadataId.toLowerCase()))
        .filter((e) => !filter.selectedOnly || filter.selectedSet.has(e.logicalName))
        .filter((e) => matches(e.logicalName, e.displayName, e.schemaName))
        .map(
            (e): SelectionRow => ({
                key: e.logicalName,
                label: e.displayName,
                cells: [
                    e.displayName,
                    <span className={styles.mono}>{e.logicalName}</span>,
                    <span className={styles.mono}>{e.schemaName}</span>,
                    e.description ? (
                        <Tooltip content={e.description} relationship="description" withArrow>
                            <span>{e.description}</span>
                        </Tooltip>
                    ) : (
                        <span className={styles.muted}>—</span>
                    ),
                    <Badge appearance="outline" size="small" color={TABLE_TYPE_COLORS[e.tableType]}>
                        {e.tableType}
                    </Badge>,
                ],
                sortValues: [e.displayName, e.logicalName, e.schemaName, e.description || undefined, e.tableType],
            }),
        );
}

/**
 * The Actions or Functions tab rows: operations of `filter.kind` that pass the filters, custom APIs and custom
 * actions first, then case-insensitive by name.
 *
 * @param operations - The environment's actions and functions; `null` (not loaded yet) gives no rows.
 * @param filter - The kind, Custom only, solution, Selected only and search filters; the search matches the name,
 * bound table and display name.
 * @param styles - The SelectionCard class names for the stacked name and secondary text cells.
 * @returns One row per matching operation, keyed by name, with name, binding, parameter count and type cells.
 */
export function buildOperationRows(operations: OperationSummary[] | null, filter: OperationRowFilter, styles: SelectionRowStyles): SelectionRow[] {
    const matches = matcher(filter.term);
    return (operations ?? [])
        .filter((o) => o.kind === filter.kind)
        .filter((o) => !filter.customApisOnly || o.isCustomApi || o.isProcessAction)
        .filter((o) => !filter.selectedSolutionId || (!!filter.solutionComponentIds && !!o.componentId && filter.solutionComponentIds.has(o.componentId.toLowerCase())))
        .filter((o) => !filter.selectedOnly || filter.selectedSet.has(o.name))
        .filter((o) => matches(o.name, o.boundTo, o.displayName))
        // Custom APIs first, then case-insensitive by name (a plain sort puts lowercase publisher
        // prefixes after hundreds of built-in PascalCase messages, past the row limit).
        .sort((a, b) => Number(b.isCustomApi || b.isProcessAction) - Number(a.isCustomApi || a.isProcessAction) || a.name.localeCompare(b.name, undefined, { sensitivity: 'base' }))
        .map((o): SelectionRow => {
            const hasDisplayName = !!o.displayName && o.displayName !== o.name;
            return {
                key: o.name,
                label: o.name,
                cells: [
                    hasDisplayName ? (
                        <span className={styles.stacked}>
                            <span>{o.displayName}</span>
                            <span className={styles.secondary}>{o.name}</span>
                        </span>
                    ) : (
                        o.name
                    ),
                    o.isBound ? `Bound to ${o.boundTo ?? '?'}` : 'Unbound',
                    o.inMetadata ? (
                        String(o.parameterCount)
                    ) : (
                        <Tooltip content="Not in $metadata; types are built from the custom API definition" relationship="description" withArrow>
                            <span className={styles.secondary}>From definition</span>
                        </Tooltip>
                    ),
                    o.isCustomApi || o.isProcessAction ? (
                        <Badge appearance="outline" size="small">
                            {operationType(o)}
                        </Badge>
                    ) : (
                        operationType(o)
                    ),
                ],
                sortValues: [
                    hasDisplayName ? o.displayName : o.name,
                    o.isBound ? `Bound to ${o.boundTo ?? '?'}` : 'Unbound',
                    o.inMetadata ? o.parameterCount : undefined,
                    operationType(o),
                ],
            };
        });
}
