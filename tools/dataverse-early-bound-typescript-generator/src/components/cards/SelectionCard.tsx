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
import { buildEntityRows, buildOperationRows } from './subcomponents/selectionRows';
import type { StepState } from '../shared/workflowSteps';

/** A Select tab, and the matching list of names in the config (tables, actions or functions). */
export type SelectionKind = 'entities' | 'actions' | 'functions';

/** Default for the `rowLimit` prop (the General setting "Rows shown in the Select tables"). */
const MAX_ROWS = 500;

/** The solution dropdown and what the chosen solution contains. */
export interface ISelectionSolutionFilter {
    /** The solutions the dropdown offers; the dropdown is disabled while it's empty. */
    solutions: SolutionSummary[];
    /** The chosen solution, or `null` for all solutions. */
    selectedId: string | null;
    /** Entity `MetadataId`s in the chosen solution, or `null` when no solution filter is active. */
    entityIds: Set<string> | null;
    /** Ids of custom API / process-action records in the chosen solution, or `null` when not filtering. */
    componentIds: Set<string> | null;
}

/** Which lists are still loading. */
export interface ISelectionLoading {
    /** The tables list; the Tables tab shows a spinner. */
    entities: boolean;
    /** The actions and functions (the `$metadata` document); the Actions and Functions tabs show a spinner. */
    operations: boolean;
    /** The chosen solution's components. */
    solution: boolean;
}

/** Props for {@link SelectionCard}. */
export interface ISelectionCardProps {
    /** The card's step in the workflow: number, title and completion badge. */
    step: StepState;
    /** The environment's tables, listed on the Tables tab. */
    entities: EntitySummary[];
    /** The environment's actions and functions, or `null` until they're loaded (see `onEnsureOperations`). */
    operations: OperationSummary[] | null;
    /** The solution dropdown's options and what the chosen solution contains. */
    solutionFilter: ISelectionSolutionFilter;
    /** Which lists are still loading. */
    loading: ISelectionLoading;
    /** The selected names per tab (logical names for tables), as stored in the config. */
    selected: Record<SelectionKind, string[]>;
    /** Names in the config that the connected environment does not have. */
    missing: Record<SelectionKind, string[]>;
    /**
     * Disables the row checkboxes and Clear (no connection or project yet, or work in progress); an empty list
     * then asks the user to connect.
     */
    disabled: boolean;
    /**
     * No project open yet: the lists stay empty and the tabs, search, solution filter, switches and Clear are
     * disabled until one is created or opened.
     * @defaultValue false
     */
    needsProject?: boolean;
    /** Called when a row's checkbox changes, with the current tab, the row's name and whether it's now checked. */
    onToggle: (kind: SelectionKind, name: string, checked: boolean) => void;
    /** Called with the current tab when Clear is clicked, to empty that tab's selection. */
    onClear: (kind: SelectionKind) => void;
    /** Called with the chosen solution's id when the solution dropdown changes, or `null` when it's cleared. */
    onSolutionChange: (solutionId: string | null) => void;
    /** Called when the actions/functions tabs are opened, so the CSDL is only fetched when needed. */
    onEnsureOperations: () => void;
    /** The most rows each table lists (the General setting); defaults to 500. */
    rowLimit?: number;
}

/** Step 2: pick tables, actions and functions. Selection is stored directly in the config. */
export function SelectionCard(props: ISelectionCardProps) {
    const { step, solutionFilter } = props;
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
                ? buildEntityRows(props.entities, { term, selectedOnly, selectedSet, solutionEntityIds: solutionFilter.entityIds }, styles)
                : buildOperationRows(
                      props.operations,
                      {
                          kind: tab === 'actions' ? 'action' : 'function',
                          term,
                          selectedOnly,
                          selectedSet,
                          customApisOnly,
                          selectedSolutionId: solutionFilter.selectedId,
                          solutionComponentIds: solutionFilter.componentIds,
                      },
                      styles,
                  ),
        [tab, term, selectedOnly, customApisOnly, selectedSet, props.entities, props.operations, solutionFilter.entityIds, solutionFilter.componentIds, solutionFilter.selectedId, styles],
    );

    const onTabSelect = (_: SelectTabEvent, data: SelectTabData) => {
        const next = data.value as SelectionKind;
        setTab(next);
        if (next !== 'entities') props.onEnsureOperations();
    };

    const loading = tab === 'entities' ? props.loading.entities : props.loading.operations;
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
                        selectedOptions={solutionFilter.selectedId ? [solutionFilter.selectedId] : []}
                        value={solutionFilter.solutions.find((s) => s.id === solutionFilter.selectedId)?.friendlyName ?? ''}
                        onOptionSelect={(_, data) => props.onSolutionChange(data.optionValue ?? null)}
                        disabled={noProject || solutionFilter.solutions.length === 0}
                    >
                        {solutionFilter.solutions.map((s) => (
                            <Option key={s.id} value={s.id} text={s.friendlyName}>
                                {`${s.friendlyName} (${s.uniqueName})`}
                            </Option>
                        ))}
                    </Dropdown>
                    {props.loading.solution && <Spinner size="tiny" label="Loading solution components…" labelPosition="after" />}
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
