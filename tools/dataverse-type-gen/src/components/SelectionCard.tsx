import { useMemo, useState } from 'react';
import {
    Badge,
    Button,
    Card,
    CardHeader,
    Checkbox,
    Dropdown,
    Option,
    SearchBox,
    Spinner,
    Switch,
    Tab,
    TabList,
    Text,
    makeStyles,
    tokens,
    type SelectTabData,
    type SelectTabEvent,
} from '@fluentui/react-components';
import type { EntitySummary, OperationSummary, SolutionSummary } from '../types';

export type SelectionKind = 'entities' | 'actions' | 'functions';

const MAX_ROWS = 500;

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
    row: {
        display: 'flex',
        alignItems: 'center',
        gap: tokens.spacingHorizontalS,
        padding: `0 ${tokens.spacingHorizontalS}`,
        borderBottom: `1px solid ${tokens.colorNeutralStroke3}`,
        ':hover': { backgroundColor: tokens.colorNeutralBackground1Hover },
    },
    rowLabel: { display: 'flex', flexDirection: 'column', flexGrow: 1, minWidth: 0, padding: `${tokens.spacingVerticalXS} 0` },
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
                .map((e) => ({
                    key: e.logicalName,
                    primary: e.displayName,
                    secondary: e.logicalName,
                    tag: e.isCustom ? 'custom' : undefined,
                }));
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
            .map((o) => {
                const binding = o.isBound ? `bound to ${o.boundTo ?? '?'}` : 'unbound';
                return {
                    key: o.name,
                    primary: o.displayName && o.displayName !== o.name ? `${o.displayName} (${o.name})` : o.name,
                    secondary: o.inMetadata
                        ? `${binding} · ${o.parameterCount} parameters`
                        : `${binding} · not in $metadata, types are built from the custom API definition`,
                    tag: o.isCustomApi ? (o.isPrivate ? 'private custom API' : 'custom API') : o.isProcessAction ? 'custom action' : o.isBound ? 'bound' : undefined,
                };
            });
    }, [tab, term, selectedOnly, customApisOnly, selectedSet, props.entities, props.operations, props.solutionEntityIds, props.solutionComponentIds, props.selectedSolutionId]);

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
                    <Tab value="entities">Tables</Tab>
                    <Tab value="actions">Actions</Tab>
                    <Tab value="functions">Functions</Tab>
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
                        shown.map((row) => (
                            <label key={row.key} className={styles.row}>
                                <Checkbox
                                    checked={selectedSet.has(row.key)}
                                    disabled={props.disabled}
                                    onChange={(_, data) => props.onToggle(tab, row.key, data.checked === true)}
                                />
                                <span className={styles.rowLabel}>
                                    <Text>{row.primary}</Text>
                                    <span className={styles.secondary}>{row.secondary}</span>
                                </span>
                                {row.tag && (
                                    <Badge appearance="outline" size="small">
                                        {row.tag}
                                    </Badge>
                                )}
                            </label>
                        ))
                    )}
                </div>
                <Text size={200}>
                    {rows.length > MAX_ROWS ? `Showing the first ${MAX_ROWS} of ${rows.length} matches, refine the search to see more.` : `${rows.length} shown.`}
                </Text>
            </div>
        </Card>
    );
}
