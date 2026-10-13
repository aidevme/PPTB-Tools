import { useMemo, useState, type ReactNode } from 'react';
import {
    Badge,
    Button,
    Card,
    CardHeader,
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
    makeStyles,
    tokens,
    type SelectTabData,
    type SelectTabEvent,
} from '@fluentui/react-components';
import { FlashRegular, MathFormulaRegular, TableRegular } from '@fluentui/react-icons';
import type { EntitySummary, OperationSummary, SolutionSummary } from '../../types';

export type SelectionKind = 'entities' | 'actions' | 'functions';

const MAX_ROWS = 500;

const ENTITY_COLUMNS = ['Display Name', 'Logical Name', 'Schema Name', 'Type'];
const OPERATION_COLUMNS = ['Name', 'Binding', 'Parameters', 'Type'];

/** One table row: the selection key, a name for the checkbox's accessible label, and the cells after it. */
interface SelectionRow {
    key: string;
    label: string;
    cells: ReactNode[];
}

function operationType(o: OperationSummary): string {
    if (o.isCustomApi) return o.isPrivate ? 'Private custom API' : 'Custom API';
    return o.isProcessAction ? 'Custom action' : 'Built-in';
}

const useStyles = makeStyles({
    body: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalS },
    toolbar: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS, flexWrap: 'wrap' },
    search: { minWidth: '260px' },
    list: {
        maxHeight: '360px',
        overflowY: 'auto',
        border: `1px solid ${tokens.colorNeutralStroke2}`,
        borderRadius: tokens.borderRadiusMedium,
    },
    row: { cursor: 'pointer' },
    rowDisabled: { cursor: 'default' },
    // Keeps the column headers visible while the list scrolls.
    headerRow: { position: 'sticky', top: 0, zIndex: 1, backgroundColor: tokens.colorNeutralBackground1 },
    headerCell: { fontWeight: tokens.fontWeightSemibold },
    stacked: { display: 'flex', flexDirection: 'column', minWidth: 0 },
    mono: { fontFamily: tokens.fontFamilyMonospace, fontSize: tokens.fontSizeBase200 },
    secondary: { color: tokens.colorNeutralForeground3, fontFamily: tokens.fontFamilyMonospace, fontSize: tokens.fontSizeBase200 },
    empty: { padding: tokens.spacingVerticalL, textAlign: 'center', color: tokens.colorNeutralForeground3 },
    summary: { display: 'flex', gap: tokens.spacingHorizontalS, alignItems: 'center', flexWrap: 'wrap' },
});

export interface SelectionCardProps {
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
    onToggle: (kind: SelectionKind, name: string, checked: boolean) => void;
    onClear: (kind: SelectionKind) => void;
    onSolutionChange: (solutionId: string | null) => void;
    /** Called when the actions/functions tabs are opened, so the CSDL is only fetched when needed. */
    onEnsureOperations: () => void;
}

/** Step 2: pick tables, actions and functions. Selection is stored directly in the config. */
export function SelectionCard(props: SelectionCardProps) {
    const styles = useStyles();
    const [tab, setTab] = useState<SelectionKind>('entities');
    const [search, setSearch] = useState('');
    const [selectedOnly, setSelectedOnly] = useState(false);
    const [customApisOnly, setCustomApisOnly] = useState(false);

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
                            e.isCustom ? (
                                <Badge appearance="outline" size="small">
                                    Custom
                                </Badge>
                            ) : (
                                'Standard'
                            ),
                        ],
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
    const shown = rows.slice(0, MAX_ROWS);

    return (
        <Card>
            <CardHeader
                header={
                    <Text weight="semibold" size={400}>
                        2. Select
                    </Text>
                }
                description={
                    <div className={styles.summary}>
                        <Badge appearance="tint">{props.selected.entities.length} tables</Badge>
                        <Badge appearance="tint">{props.selected.actions.length} actions</Badge>
                        <Badge appearance="tint">{props.selected.functions.length} functions</Badge>
                        <Text size={200}>Tables referenced by a selected action or function are generated automatically.</Text>
                    </div>
                }
            />
            <div className={styles.body}>
                <TabList selectedValue={tab} onTabSelect={onTabSelect}>
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
                        onChange={(_, data) => setSearch(data.value)}
                    />
                    <Dropdown
                        placeholder="All solutions"
                        clearable
                        selectedOptions={props.selectedSolutionId ? [props.selectedSolutionId] : []}
                        value={props.solutions.find((s) => s.id === props.selectedSolutionId)?.friendlyName ?? ''}
                        onOptionSelect={(_, data) => props.onSolutionChange(data.optionValue ?? null)}
                        disabled={props.solutions.length === 0}
                    >
                        {props.solutions.map((s) => (
                            <Option key={s.id} value={s.id} text={s.friendlyName}>
                                {`${s.friendlyName} (${s.uniqueName})`}
                            </Option>
                        ))}
                    </Dropdown>
                    {props.loadingSolution && <Spinner size="tiny" label="Loading solution components…" labelPosition="after" />}
                    {tab !== 'entities' && (
                        <Switch label="Custom only" checked={customApisOnly} onChange={(_, data) => setCustomApisOnly(data.checked)} />
                    )}
                    <Switch label="Selected only" checked={selectedOnly} onChange={(_, data) => setSelectedOnly(data.checked)} />
                    <Button appearance="subtle" size="small" disabled={props.disabled || props.selected[tab].length === 0} onClick={() => props.onClear(tab)}>
                        Clear {tab}
                    </Button>
                </div>
                {missing.length > 0 && (
                    <Text size={200}>
                        Not found in this environment (kept in the config, skipped when generating): <b>{missing.join(', ')}</b>
                    </Text>
                )}
                <div className={styles.list}>
                    {loading ? (
                        <div className={styles.empty}>
                            <Spinner label={tab === 'entities' ? 'Loading tables…' : 'Loading the $metadata document…'} />
                        </div>
                    ) : shown.length === 0 ? (
                        <div className={styles.empty}>{props.disabled ? 'Connect to an environment to list items.' : 'Nothing matches.'}</div>
                    ) : (
                        <Table aria-label={tab === 'entities' ? 'Tables' : tab === 'actions' ? 'Actions' : 'Functions'} size="small">
                            <TableHeader>
                                <TableRow className={styles.headerRow}>
                                    <TableSelectionCell type="checkbox" invisible />
                                    {(tab === 'entities' ? ENTITY_COLUMNS : OPERATION_COLUMNS).map((column) => (
                                        <TableHeaderCell key={column} className={styles.headerCell}>
                                            {column}
                                        </TableHeaderCell>
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
                <Text size={200}>
                    {rows.length > MAX_ROWS ? `Showing the first ${MAX_ROWS} of ${rows.length} matches, refine the search to see more.` : `${rows.length} shown.`}
                </Text>
            </div>
        </Card>
    );
}
