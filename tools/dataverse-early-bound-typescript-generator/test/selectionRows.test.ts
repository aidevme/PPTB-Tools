/**
 * The Select card's row builders: which entities and operations each tab lists, in which order, and the values
 * the columns sort by.
 */
import { describe, expect, it } from 'vitest';
import { buildEntityRows, buildOperationRows, operationType, type EntityRowFilter, type OperationRowFilter } from '../src/components/cards/subcomponents/selectionRows';
import type { EntitySummary, OperationSummary } from '../src/types';

const STYLES = { mono: 'mono', muted: 'muted', stacked: 'stacked', secondary: 'secondary' };

const entity = (logicalName: string, extra: Partial<EntitySummary> = {}): EntitySummary => ({
    logicalName,
    schemaName: logicalName,
    displayName: logicalName,
    description: '',
    metadataId: `ID-${logicalName}`,
    isCustom: false,
    isManaged: true,
    tableType: 'Standard',
    ...extra,
});

const operation = (name: string, extra: Partial<OperationSummary> = {}): OperationSummary => ({
    name,
    kind: 'action',
    isBound: false,
    parameterCount: 1,
    isCustomApi: false,
    isProcessAction: false,
    isPrivate: false,
    inMetadata: true,
    ...extra,
});

const entityFilter = (extra: Partial<EntityRowFilter> = {}): EntityRowFilter => ({ term: '', selectedOnly: false, selectedSet: new Set(), solutionEntityIds: null, ...extra });

const operationFilter = (extra: Partial<OperationRowFilter> = {}): OperationRowFilter => ({
    kind: 'action',
    term: '',
    selectedOnly: false,
    selectedSet: new Set(),
    customApisOnly: false,
    selectedSolutionId: null,
    solutionComponentIds: null,
    ...extra,
});

const keys = (rows: Array<{ key: string }>) => rows.map((r) => r.key);

describe('buildEntityRows', () => {
    const ENTITIES = [entity('account', { displayName: 'Account', description: 'Customers' }), entity('contoso_project', { displayName: 'Project', schemaName: 'contoso_Project' })];

    it('keeps the input order and the sort values of each column', () => {
        const rows = buildEntityRows(ENTITIES, entityFilter(), STYLES);
        expect(keys(rows)).toEqual(['account', 'contoso_project']);
        expect(rows[0].label).toBe('Account');
        expect(rows[0].sortValues).toEqual(['Account', 'account', 'account', 'Customers', 'Standard']);
        expect(rows[1].sortValues[3]).toBeUndefined();
    });

    it('searches the logical, display and schema names case-insensitively', () => {
        expect(keys(buildEntityRows(ENTITIES, entityFilter({ term: 'proj' }), STYLES))).toEqual(['contoso_project']);
        expect(keys(buildEntityRows(ENTITIES, entityFilter({ term: 'contoso_p' }), STYLES))).toEqual(['contoso_project']);
        expect(keys(buildEntityRows(ENTITIES, entityFilter({ term: 'customers' }), STYLES))).toEqual([]);
    });

    it('applies the solution filter by lowercased MetadataId and the selected-only switch', () => {
        expect(keys(buildEntityRows(ENTITIES, entityFilter({ solutionEntityIds: new Set(['id-account']) }), STYLES))).toEqual(['account']);
        expect(keys(buildEntityRows(ENTITIES, entityFilter({ selectedOnly: true, selectedSet: new Set(['contoso_project']) }), STYLES))).toEqual(['contoso_project']);
    });
});

describe('buildOperationRows', () => {
    const OPERATIONS = [
        operation('WinOpportunity'),
        operation('contoso_Escalate', { isCustomApi: true, componentId: 'C1', displayName: 'Escalate', isBound: true, boundTo: 'queueitem', inMetadata: false }),
        operation('ActivateQuote'),
        operation('new_Approve', { isProcessAction: true, componentId: 'C2' }),
        operation('WhoAmI', { kind: 'function' }),
    ];

    it('lists only the tab kind, custom APIs and custom actions first, then case-insensitive by name', () => {
        expect(keys(buildOperationRows(OPERATIONS, operationFilter(), STYLES))).toEqual(['contoso_Escalate', 'new_Approve', 'ActivateQuote', 'WinOpportunity']);
        expect(keys(buildOperationRows(OPERATIONS, operationFilter({ kind: 'function' }), STYLES))).toEqual(['WhoAmI']);
        expect(buildOperationRows(null, operationFilter(), STYLES)).toEqual([]);
    });

    it('applies the custom-APIs-only switch, the solution filter and the search', () => {
        expect(keys(buildOperationRows(OPERATIONS, operationFilter({ customApisOnly: true }), STYLES))).toEqual(['contoso_Escalate', 'new_Approve']);
        expect(keys(buildOperationRows(OPERATIONS, operationFilter({ selectedSolutionId: 's', solutionComponentIds: new Set(['c2']) }), STYLES))).toEqual(['new_Approve']);
        // A chosen solution whose components are still loading matches nothing.
        expect(keys(buildOperationRows(OPERATIONS, operationFilter({ selectedSolutionId: 's' }), STYLES))).toEqual([]);
        expect(keys(buildOperationRows(OPERATIONS, operationFilter({ term: 'queue' }), STYLES))).toEqual(['contoso_Escalate']);
        expect(keys(buildOperationRows(OPERATIONS, operationFilter({ selectedOnly: true, selectedSet: new Set(['WinOpportunity']) }), STYLES))).toEqual(['WinOpportunity']);
    });

    it('sorts by display name, binding, parameter count (none when not in $metadata) and type', () => {
        const [escalate] = buildOperationRows(OPERATIONS, operationFilter(), STYLES);
        expect(escalate.label).toBe('contoso_Escalate');
        expect(escalate.sortValues).toEqual(['Escalate', 'Bound to queueitem', undefined, 'Custom API']);
    });
});

describe('operationType', () => {
    it('names custom APIs, private custom APIs, custom actions and built-in messages', () => {
        expect(operationType(operation('a', { isCustomApi: true }))).toBe('Custom API');
        expect(operationType(operation('a', { isCustomApi: true, isPrivate: true }))).toBe('Private custom API');
        expect(operationType(operation('a', { isProcessAction: true }))).toBe('Custom action');
        expect(operationType(operation('a'))).toBe('Built-in');
    });
});
