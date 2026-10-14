import { useMemo, useState, type ReactNode } from 'react';
import {
    Badge,
    Button,
    Dropdown,
    Option,
    SearchBox,
    Spinner,
    Switch,
    Tab,
    TabList,
    Table,
    TableBody,
    TableCell,
    TableCellLayout,
    TableHeader,
    TableHeaderCell,
    TableRow,
    TableSelectionCell,
    Text,
    Tooltip,
    type BadgeProps,
    type SelectTabData,
    type SortDirection,
    type SelectTabEvent,
} from '@fluentui/react-components';
import { FlashRegular, MathFormulaRegular, TableRegular } from '@fluentui/react-icons';
import type { EntitySummary, OperationSummary, SolutionSummary, TableType } from '../../types';
import { useSelectionCardStyles } from '../../styles';
import { StepCard } from '../shared/StepCard';
import type { StepState } from '../shared/workflowSteps';

export type SelectionKind = 'entities' | 'actions' | 'functions';

const MAX_ROWS = 500;

/** A column header: its label and the explanation shown in its tooltip. */
interface SelectionColumn {
    label: string;
    help: ReactNode;
}

const ENTITY_COLUMNS: SelectionColumn[] = [
    {
        label: 'Display Name',
        help: <><strong>Display Name:</strong> the table's name as shown in Power Apps, in the user's language. Click to sort by display name.</>,
    },
    {
        label: 'Logical Name',
        help: <><strong>Logical Name:</strong> the lowercase name used in the Web API and stored in .dataverse-gen.json. Generated file names are based on it. Click to sort by logical name.</>,
    },
    {
        label: 'Schema Name',
        help: <><strong>Schema Name:</strong> the PascalCase name the generated interface and metadata constants are named after. Click to sort by schema name.</>,
    },
    {
        label: 'Description',
        help: <><strong>Description:</strong> the table's description from its metadata; hover over a description to read all of it. Tables without one are listed last. Click to sort by description.</>,
    },
    {
        label: 'Type',
        help: (
            <>
                <strong>Type:</strong> the kind of table, as Power Apps shows it.
                <ul>
                    <li><strong>Standard</strong>: an ordinary table stored in Dataverse</li>
                    <li><strong>Activity</strong>: an activity such as a task, email or appointment, with a subject and dates</li>
                    <li><strong>Virtual</strong>: data from an external source, shown in Dataverse but not stored in it</li>
                    <li><strong>Elastic</strong>: built for very large data volumes (tens of millions of rows)</li>
                </ul>
                Click to sort by type.
            </>
        ),
    },
];

/** Columns of the Actions tab: custom APIs, custom process actions and built-in actions. */
const CUSTOMAPI_COLUMNS: SelectionColumn[] = [
    {
        label: 'Name',
        help: <><strong>Name:</strong> the action's unique name, used in .dataverse-gen.json and for the generated request type, with its display name above it when it has a different one. Click to sort by name.</>,
    },
    {
        label: 'Binding',
        help: (
            <>
                <strong>Binding:</strong> how the action is called.
                <ul>
                    <li><strong>Bound to &lt;table&gt;</strong>: called on a record of that table, which is generated automatically</li>
                    <li><strong>Unbound</strong>: called on its own</li>
                </ul>
                Click to sort by binding.
            </>
        ),
    },
    {
        label: 'Parameters',
        help: <><strong>Parameters:</strong> the number of request parameters in $metadata. "From definition" means the action isn't in $metadata (a private custom API), so its types are built from the custom API record; these are listed last. Click to sort by parameter count.</>,
    },
    {
        label: 'Type',
        help: (
            <>
                <strong>Type:</strong> where the action comes from.
                <ul>
                    <li><strong>Custom API</strong> / <strong>Private custom API</strong>: a customapi record</li>
                    <li><strong>Custom action</strong>: a custom process action</li>
                    <li><strong>Built-in</strong>: a standard Dataverse action</li>
                </ul>
                Click to sort by type.
            </>
        ),
    },
];

/** Columns of the Functions tab: custom API functions and built-in functions (process actions are never functions). */
const FUNCTION_COLUMNS: SelectionColumn[] = [
    {
        label: 'Name',
        help: <><strong>Name:</strong> the function's unique name, used in .dataverse-gen.json and for the generated request type, with its display name above it when it has a different one. Click to sort by name.</>,
    },
    {
        label: 'Binding',
        help: (
            <>
                <strong>Binding:</strong> how the function is called.
                <ul>
                    <li><strong>Bound to &lt;table&gt;</strong>: called on a record or collection of that table, which is generated automatically</li>
                    <li><strong>Unbound</strong>: called on its own</li>
                </ul>
                Click to sort by binding.
            </>
        ),
    },
    {
        label: 'Parameters',
        help: <><strong>Parameters:</strong> the number of parameters in $metadata. "From definition" means the function isn't in $metadata (a private custom API), so its types are built from the custom API record; these are listed last. Click to sort by parameter count.</>,
    },
    {
        label: 'Type',
        help: (
            <>
                <strong>Type:</strong> where the function comes from.
                <ul>
                    <li><strong>Custom API</strong> / <strong>Private custom API</strong>: a customapi record marked as a function</li>
                    <li><strong>Built-in</strong>: a standard Dataverse function</li>
                </ul>
                Click to sort by type.
            </>
        ),
    },
];

/** A value to sort a column by; `undefined` (no value) is always listed last. */
type SortValue = string | number | undefined;

interface SortState {
    /** Index into the tab's columns. */
    column: number;
    direction: SortDirection;
}

/**
 * One table row: the selection key, a name for the checkbox's accessible label, the cells after it, and one sort
 * value per cell.
 */
interface SelectionRow {
    key: string;
    label: string;
    cells: ReactNode[];
    sortValues: SortValue[];
}

function compareSortValues(a: SortValue, b: SortValue, direction: SortDirection): number {
    if (a === undefined || b === undefined) return a === b ? 0 : a === undefined ? 1 : -1;
    const result = typeof a === 'number' && typeof b === 'number' ? a - b : String(a).localeCompare(String(b), undefined, { sensitivity: 'base', numeric: true });
    return direction === 'ascending' ? result : -result;
}

/**
 * Rows in the order to list them: their given order until a column is sorted, then by that column, with ties in
 * their given order. Rows without a value for the column come last in either direction.
 */
export function sortSelectionRows<T extends { sortValues: SortValue[] }>(rows: T[], sort: SortState | null): T[] {
    if (!sort) return rows;
    return rows
        .map((row, index) => ({ row, index }))
        .sort((a, b) => compareSortValues(a.row.sortValues[sort.column], b.row.sortValues[sort.column], sort.direction) || a.index - b.index)
        .map(({ row }) => row);
}

/**
 * Badge colour per table type, from Fluent UI's semantic palette so it adapts to light and dark themes. Red
 * (danger/severe) is avoided, since nothing here is an error.
 */
const TABLE_TYPE_COLORS: Record<TableType, BadgeProps['color']> = {
    Standard: 'informative',
    Activity: 'brand',
    Virtual: 'warning',
    Elastic: 'success',
};

function operationType(o: OperationSummary): string {
    if (o.isCustomApi) return o.isPrivate ? 'Private custom API' : 'Custom API';
    return o.isProcessAction ? 'Custom action' : 'Built-in';
}

export interface SelectionCardProps {
    step: StepState;
    entities: EntitySummary[];
    operations: OperationSummary[] | null;
    solutions: SolutionSummary[];
    /** Entity `MetadataId`s in the chosen solution, or `null` when no solution filter is active. */
    solutionEntityIds: Set<string> | null;
    /** Ids of custom API / process-action records in the chosen solution, or `null` when not filtering. */
    solutionComponentIds: Set<string> | null;
    selectedSolutionId: string | null;
    loadingEntities: boolean;
    loadingOperations: boolean;
    loadingSolution: boolean;
    selected: Record<SelectionKind, string[]>;
    /** Names in the config that the connected environment does not have. */
    missing: Record<SelectionKind, string[]>;
    disabled: boolean;
    /**
     * No project open yet: the lists stay empty and the tabs, search, solution filter, switches and Clear are
     * disabled until one is created or opened.
     */
    needsProject?: boolean;
    onToggle: (kind: SelectionKind, name: string, checked: boolean) => void;
    onClear: (kind: SelectionKind) => void;
    onSolutionChange: (solutionId: string | null) => void;
    /** Called when the actions/functions tabs are opened, so the CSDL is only fetched when needed. */
    onEnsureOperations: () => void;
}

/** Step 2: pick tables, actions and functions. Selection is stored directly in the config. */
export function SelectionCard(props: SelectionCardProps) {
    const { step } = props;
    const styles = useSelectionCardStyles();
    /** Nothing to browse until a project is open, so every control is disabled. */
    const noProject = !!props.needsProject;
    const [tab, setTab] = useState<SelectionKind>('entities');
    const [search, setSearch] = useState('');
    const [selectedOnly, setSelectedOnly] = useState(false);
    const [customApisOnly, setCustomApisOnly] = useState(false);
    // Each tab keeps its own sort, since their columns differ.
    const [sorts, setSorts] = useState<Record<SelectionKind, SortState | null>>({ entities: null, actions: null, functions: null });
    const sort = sorts[tab];

    const selectedSet = useMemo(() => new Set(props.selected[tab]), [props.selected, tab]);
    const term = search.trim().toLowerCase();

    const rows = useMemo(() => {
        const matches = (...values: Array<string | undefined>) => !term || values.some((v) => v?.toLowerCase().includes(term));
        if (tab === 'entities') {
            return props.entities
                .filter((e) => !props.solutionEntityIds || props.solutionEntityIds.has(e.metadataId.toLowerCase()))
                .filter((e) => !selectedOnly || selectedSet.has(e.logicalName))
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
        const kind = tab === 'actions' ? 'action' : 'function';
        return (props.operations ?? [])
            .filter((o) => o.kind === kind)
            .filter((o) => !customApisOnly || o.isCustomApi || o.isProcessAction)
            .filter((o) => !props.selectedSolutionId || (!!props.solutionComponentIds && !!o.componentId && props.solutionComponentIds.has(o.componentId.toLowerCase())))
            .filter((o) => !selectedOnly || selectedSet.has(o.name))
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
    }, [tab, term, selectedOnly, customApisOnly, selectedSet, props.entities, props.operations, props.solutionEntityIds, props.solutionComponentIds, props.selectedSolutionId, styles]);

    const onTabSelect = (_: SelectTabEvent, data: SelectTabData) => {
        const next = data.value as SelectionKind;
        setTab(next);
        if (next !== 'entities') props.onEnsureOperations();
    };

    const loading = tab === 'entities' ? props.loadingEntities : props.loadingOperations;
    const missing = props.missing[tab];
    // Sorted before the row limit, so the first rows shown are the first of all matches.
    const sorted = useMemo(() => sortSelectionRows(rows, sort), [rows, sort]);
    const shown = sorted.slice(0, MAX_ROWS);
    const columns = tab === 'entities' ? ENTITY_COLUMNS : tab === 'actions' ? CUSTOMAPI_COLUMNS : FUNCTION_COLUMNS;

    const toggleSort = (column: number) =>
        setSorts((current) => {
            const active = current[tab];
            const direction: SortDirection = active?.column === column && active.direction === 'ascending' ? 'descending' : 'ascending';
            return { ...current, [tab]: { column, direction } };
        });

    return (
        <StepCard step={step} description={
                <div className={styles.summary}>
                    <Badge appearance="tint">{props.selected.entities.length} tables</Badge>
                    <Badge appearance="tint">{props.selected.actions.length} actions</Badge>
                    <Badge appearance="tint">{props.selected.functions.length} functions</Badge>
                    <Text size={200}>Tables referenced by a selected action or function are generated automatically.</Text>
                </div>
            }>
            <div className={styles.body}>
                <TabList selectedValue={tab} onTabSelect={onTabSelect} disabled={noProject}>
                    <Tooltip content="Dataverse tables to generate early-bound interfaces, metadata and choice enums for" relationship="description" withArrow>
                        <Tab value="entities" icon={<TableRegular />}>
                            Tables
                        </Tab>
                    </Tooltip>
                    <Tooltip content="Dataverse actions (custom APIs, custom process actions and built-in messages) to generate request types for" relationship="description" withArrow>
                        <Tab value="actions" icon={<FlashRegular />}>
                            Actions
                        </Tab>
                    </Tooltip>
                    <Tooltip content="Dataverse functions (custom APIs and built-in functions) to generate request types for" relationship="description" withArrow>
                        <Tab value="functions" icon={<MathFormulaRegular />}>
                            Functions
                        </Tab>
                    </Tooltip>
                </TabList>
                <div className={styles.toolbar}>
                    <SearchBox
                        className={styles.search}
                        placeholder={tab === 'entities' ? 'Search by display or logical name' : 'Search by name or display name'}
                        value={search}
                        disabled={noProject}
                        onChange={(_, data) => setSearch(data.value)}
                    />
                    <Dropdown
                        placeholder="All solutions"
                        clearable
                        selectedOptions={props.selectedSolutionId ? [props.selectedSolutionId] : []}
                        value={props.solutions.find((s) => s.id === props.selectedSolutionId)?.friendlyName ?? ''}
                        onOptionSelect={(_, data) => props.onSolutionChange(data.optionValue ?? null)}
                        disabled={noProject || props.solutions.length === 0}
                    >
                        {props.solutions.map((s) => (
                            <Option key={s.id} value={s.id} text={s.friendlyName}>
                                {`${s.friendlyName} (${s.uniqueName})`}
                            </Option>
                        ))}
                    </Dropdown>
                    {props.loadingSolution && <Spinner size="tiny" label="Loading solution components…" labelPosition="after" />}
                    {tab !== 'entities' && (
                        <Switch label="Custom only" checked={customApisOnly} disabled={noProject} onChange={(_, data) => setCustomApisOnly(data.checked)} />
                    )}
                    <Switch label="Selected only" checked={selectedOnly} disabled={noProject} onChange={(_, data) => setSelectedOnly(data.checked)} />
                    <Button appearance="subtle" size="small" disabled={noProject || props.disabled || props.selected[tab].length === 0} onClick={() => props.onClear(tab)}>
                        Clear {tab}
                    </Button>
                </div>
                {missing.length > 0 && (
                    <Text size={200}>
                        Not found in this environment (kept in the config, skipped when generating): <b>{missing.join(', ')}</b>
                    </Text>
                )}
                <div className={styles.list}>
                    {props.needsProject ? (
                        <div className={styles.empty}>Create a new project or open an existing one (step 1) to list tables, actions and functions.</div>
                    ) : loading ? (
                        <div className={styles.empty}>
                            <Spinner label={tab === 'entities' ? 'Loading tables…' : 'Loading the $metadata document…'} />
                        </div>
                    ) : shown.length === 0 ? (
                        <div className={styles.empty}>{props.disabled ? 'Connect to an environment to list items.' : 'Nothing matches.'}</div>
                    ) : (
                        <Table aria-label={tab === 'entities' ? 'Tables' : tab === 'actions' ? 'Actions' : 'Functions'} size="small" sortable>
                            <TableHeader>
                                <TableRow className={styles.headerRow}>
                                    <TableSelectionCell type="checkbox" invisible />
                                    {columns.map((column, index) => (
                                        // Wrapping the cell means the tooltip opens on hover and when its sort button gets focus.
                                        <Tooltip
                                            key={column.label}
                                            content={{ children: column.help, className: styles.headerTooltip }}
                                            relationship="description"
                                            positioning="above"
                                            withArrow
                                        >
                                            <TableHeaderCell
                                                className={styles.headerCell}
                                                sortDirection={sort?.column === index ? sort.direction : undefined}
                                                onClick={() => toggleSort(index)}
                                            >
                                                {column.label}
                                            </TableHeaderCell>
                                        </Tooltip>
                                    ))}
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {shown.map((row) => {
                                    const checked = selectedSet.has(row.key);
                                    const toggleRow = () => {
                                        if (!props.disabled) props.onToggle(tab, row.key, !checked);
                                    };
                                    return (
                                        <TableRow
                                            key={row.key}
                                            className={props.disabled ? styles.rowDisabled : styles.row}
                                            aria-selected={checked}
                                            appearance={checked ? 'brand' : 'none'}
                                            tabIndex={0}
                                            onClick={toggleRow}
                                            onKeyDown={(e) => {
                                                if (e.key === ' ' || e.key === 'Enter') {
                                                    e.preventDefault();
                                                    toggleRow();
                                                }
                                            }}
                                        >
                                            <TableSelectionCell
                                                type="checkbox"
                                                checked={checked}
                                                checkboxIndicator={{ 'aria-label': `Select ${row.label}`, disabled: props.disabled }}
                                            />
                                            {row.cells.map((cell, index) => (
                                                <TableCell key={index}>
                                                    <TableCellLayout truncate>{cell}</TableCellLayout>
                                                </TableCell>
                                            ))}
                                        </TableRow>
                                    );
                                })}
                            </TableBody>
                        </Table>
                    )}
                </div>
                {!props.needsProject && (
                    <Text size={200}>
                        {rows.length > MAX_ROWS ? `Showing the first ${MAX_ROWS} of ${rows.length} matches, refine the search to see more.` : `${rows.length} shown.`}
                    </Text>
                )}
            </div>
        </StepCard>
    );
}
