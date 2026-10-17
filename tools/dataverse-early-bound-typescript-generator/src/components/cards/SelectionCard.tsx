import { useMemo, useState } from 'react';
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
    Text,
    Tooltip,
    type SelectTabData,
    type SelectTabEvent,
} from '@fluentui/react-components';
import { FlashRegular, MathFormulaRegular, TableRegular } from '@fluentui/react-icons';
import type { EntitySummary, OperationSummary, SolutionSummary } from '../../types';
import { useSelectionCardStyles } from '../../styles';
import { nextSort, sortSelectionRows, type SortState } from '../shared/sorting';
import { StepCard } from '../shared/StepCard';
import { SelectionTable } from '../tables/SelectionTable';
import { ACTION_COLUMNS, ENTITY_COLUMNS, FUNCTION_COLUMNS } from '../tables/selectionColumns';
import { buildEntityRows, buildOperationRows } from './selectionRows';
import type { StepState } from '../shared/workflowSteps';

export type SelectionKind = 'entities' | 'actions' | 'functions';

/** Default for the `rowLimit` prop (the General setting "Rows shown in the Select tables"). */
const MAX_ROWS = 500;

export interface ISelectionCardProps {
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
    /** The most rows each table lists (the General setting); defaults to 500. */
    rowLimit?: number;
}

/** Step 2: pick tables, actions and functions. Selection is stored directly in the config. */
export function SelectionCard(props: ISelectionCardProps) {
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

    const rows = useMemo(
        () =>
            tab === 'entities'
                ? buildEntityRows(props.entities, { term, selectedOnly, selectedSet, solutionEntityIds: props.solutionEntityIds }, styles)
                : buildOperationRows(
                      props.operations,
                      {
                          kind: tab === 'actions' ? 'action' : 'function',
                          term,
                          selectedOnly,
                          selectedSet,
                          customApisOnly,
                          selectedSolutionId: props.selectedSolutionId,
                          solutionComponentIds: props.solutionComponentIds,
                      },
                      styles,
                  ),
        [tab, term, selectedOnly, customApisOnly, selectedSet, props.entities, props.operations, props.solutionEntityIds, props.solutionComponentIds, props.selectedSolutionId, styles],
    );

    const onTabSelect = (_: SelectTabEvent, data: SelectTabData) => {
        const next = data.value as SelectionKind;
        setTab(next);
        if (next !== 'entities') props.onEnsureOperations();
    };

    const loading = tab === 'entities' ? props.loadingEntities : props.loadingOperations;
    const missing = props.missing[tab];
    // Sorted before the row limit, so the first rows shown are the first of all matches.
    const sorted = useMemo(() => sortSelectionRows(rows, sort), [rows, sort]);
    const rowLimit = props.rowLimit ?? MAX_ROWS;
    const shown = sorted.slice(0, rowLimit);
    const columns = tab === 'entities' ? ENTITY_COLUMNS : tab === 'actions' ? ACTION_COLUMNS : FUNCTION_COLUMNS;

    const toggleSort = (column: number) => setSorts((current) => ({ ...current, [tab]: nextSort(current[tab], column) }));

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
                        aria-label="Filter by solution"
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
                        <SelectionTable
                            ariaLabel={tab === 'entities' ? 'Tables' : tab === 'actions' ? 'Actions' : 'Functions'}
                            columns={columns}
                            rows={shown}
                            sort={sort}
                            onToggleSort={toggleSort}
                            selectedKeys={selectedSet}
                            disabled={!!props.disabled}
                            onToggleRow={(key, checked) => props.onToggle(tab, key, checked)}
                        />
                    )}
                </div>
                {!props.needsProject && (
                    <Text size={200}>
                        {rows.length > rowLimit ? `Showing the first ${rowLimit} of ${rows.length} matches, refine the search to see more.` : `${rows.length} shown.`}
                    </Text>
                )}
            </div>
        </StepCard>
    );
}

/** @deprecated Renamed to `ISelectionCardProps`. */
export type SelectionCardProps = ISelectionCardProps;
