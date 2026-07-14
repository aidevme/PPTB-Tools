import { useState } from "react";
import {
    Button,
    Divider,
    DrawerBody,
    DrawerHeader,
    DrawerHeaderTitle,
    Link,
    mergeClasses,
    OverlayDrawer,
    Tab,
    TabList,
    Table,
    TableBody,
    TableCell,
    TableHeader,
    TableHeaderCell,
    TableRow,
    Text,
    Tooltip,
    type SelectTabData,
    type SelectTabEvent,
    type SortDirection,
} from "@fluentui/react-components";
import {
    Apps20Regular,
    ChevronLeft20Regular,
    ChevronRight20Regular,
    Dismiss24Regular,
    Open20Regular,
    Table20Regular,
    Target20Regular,
} from "@fluentui/react-icons";
import type { PcfControl } from "../../../services";
import { useToolContext } from "../../../services/pptbtoolcontextservice";
import { useDebuggerPanelStyles } from "../../../styles";
import {
    ARIA_LABEL_CLOSE,
    ARIA_LABEL_NEXT_PAGE,
    ARIA_LABEL_PREVIOUS_PAGE,
    ATTRIBUTE_WORD,
    COLUMN_LABEL_COMPATIBLE_DATA_TYPES,
    COLUMN_LABEL_CONTROL_TYPE,
    COLUMN_LABEL_DISPLAY_NAME,
    COLUMN_LABEL_LOGICAL_NAME,
    COLUMN_LABEL_MANIFEST_VERSION,
    COLUMN_LABEL_NAME,
    COLUMN_LABEL_PARAMETERS,
    COLUMN_LABEL_TEMPLATE_TYPE,
    COLUMN_LABEL_TYPE,
    CONTROL_TYPE_STANDARD_LABEL,
    CONTROL_TYPE_VIRTUAL_LABEL,
    DRAWER_TITLE,
    LABEL_ENTITIES_PREFIX,
    LABEL_PCF_CONTROLS_PREFIX,
    LABEL_SELECTED_BPF,
    LABEL_SELECTED_PUBLISHER_ID,
    LABEL_SELECTED_SOLUTION_ID,
    NONE_TEXT,
    PAGE_LABEL_PREFIX,
    PAGE_LABEL_SEPARATOR,
    PCF_CONTROL_WORD,
    TAB_LABEL_ENTITIES,
    TAB_LABEL_PCF_CONTROLS,
    TAB_LABEL_SCOPE,
    TOOLTIP_COLUMN_COMPATIBLE_DATA_TYPES,
    TOOLTIP_COLUMN_CONTROL_TYPE,
    TOOLTIP_COLUMN_DISPLAY_NAME,
    TOOLTIP_COLUMN_LOGICAL_NAME,
    TOOLTIP_COLUMN_MANIFEST_VERSION,
    TOOLTIP_COLUMN_NAME,
    TOOLTIP_COLUMN_PARAMETERS,
    TOOLTIP_COLUMN_TEMPLATE_TYPE,
    TOOLTIP_COLUMN_TYPE,
    TOOLTIP_TAB_ENTITIES,
    TOOLTIP_TAB_PCF_CONTROLS,
    TOOLTIP_TAB_SCOPE,
    VERSION_UNKNOWN_LABEL,
} from "../../../consts";
import { PcfDetailsPanel } from "../PcfDetailsPanel";

export interface IDebuggerPanelProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

type DebuggerTab = "scope" | "entities" | "pcfControls";

/** Max attribute rows shown per page in each entity's attribute table, and max PCF control rows
 * shown per page in the "PCF Controls" tab. */
const ATTRIBUTES_PAGE_SIZE = 20;

type PcfControlSortColumn = "name" | "controlType" | "templateType" | "version" | "compatibleDataTypes" | "parameters";

const PCF_CONTROL_SORT_VALUE: Record<PcfControlSortColumn, (pcf: PcfControl) => string | number> = {
    name: (pcf) => pcf.controlName.toLowerCase(),
    controlType: (pcf) => (pcf.isVirtual ? CONTROL_TYPE_VIRTUAL_LABEL : CONTROL_TYPE_STANDARD_LABEL),
    templateType: (pcf) => pcf.templateType.toLowerCase(),
    version: (pcf) => pcf.version.toLowerCase(),
    compatibleDataTypes: (pcf) => pcf.compatibleDataTypes.join(", ").toLowerCase(),
    parameters: (pcf) => pcf.parameters.length,
};

function sortPcfControls(controls: PcfControl[], column: PcfControlSortColumn | null, direction: SortDirection): PcfControl[] {
    if (!column) return controls;

    const getValue = PCF_CONTROL_SORT_VALUE[column];
    const factor = direction === "ascending" ? 1 : -1;

    return [...controls].sort((a, b) => {
        const valueA = getValue(a);
        const valueB = getValue(b);
        if (valueA < valueB) return -1 * factor;
        if (valueA > valueB) return 1 * factor;
        return 0;
    });
}

/** Overlay drawer for in-app debugging tools, opened from the `Footer`'s "Debugger" button. */
export function DebuggerPanel({ open, onOpenChange }: IDebuggerPanelProps) {
    const styles = useDebuggerPanelStyles();
    const { bpfProcesses, selectedBpfId, selectedSolutionId, selectedPublisherId, entityMetadataInfos, pcfControls } = useToolContext();
    const selectedBpfName = bpfProcesses.find((b) => b.workflowid === selectedBpfId)?.name;
    const [activeTab, setActiveTab] = useState<DebuggerTab>("scope");
    const [pageByEntity, setPageByEntity] = useState<Record<string, number>>({});
    const [pcfControlsPage, setPcfControlsPage] = useState(1);
    const [isPcfDetailsOpen, setIsPcfDetailsOpen] = useState(false);
    const [selectedPcfForDetails, setSelectedPcfForDetails] = useState<PcfControl | undefined>(undefined);

    const handleOpenPcfDetails = (pcf: PcfControl) => {
        setSelectedPcfForDetails(pcf);
        setIsPcfDetailsOpen(true);
    };

    const [pcfControlSort, setPcfControlSort] = useState<{ column: PcfControlSortColumn; direction: SortDirection } | null>(null);

    const togglePcfControlSort = (column: PcfControlSortColumn) => {
        setPcfControlSort((prev) =>
            prev?.column === column
                ? { column, direction: prev.direction === "ascending" ? "descending" : "ascending" }
                : { column, direction: "ascending" },
        );
    };

    const totalPcfControls = pcfControls.length;
    const totalPcfControlsPages = Math.max(1, Math.ceil(totalPcfControls / ATTRIBUTES_PAGE_SIZE));
    const currentPcfControlsPage = Math.min(pcfControlsPage, totalPcfControlsPages);
    const sortedPcfControls = sortPcfControls(pcfControls, pcfControlSort?.column ?? null, pcfControlSort?.direction ?? "ascending");
    const pagedPcfControls = sortedPcfControls.slice(
        (currentPcfControlsPage - 1) * ATTRIBUTES_PAGE_SIZE,
        currentPcfControlsPage * ATTRIBUTES_PAGE_SIZE,
    );

    const handleTabSelect = (_: SelectTabEvent, data: SelectTabData) => {
        setActiveTab(data.value as DebuggerTab);
    };

    return (
        <>
            <OverlayDrawer position="end" size="full" open={open} onOpenChange={(_, data) => onOpenChange(data.open)}>
                <DrawerHeader>
                <DrawerHeaderTitle
                    action={
                        <Button
                            appearance="subtle"
                            aria-label={ARIA_LABEL_CLOSE}
                            icon={<Dismiss24Regular />}
                            onClick={() => onOpenChange(false)}
                        />
                    }
                >
                    {DRAWER_TITLE}
                </DrawerHeaderTitle>
            </DrawerHeader>
            <DrawerBody className={styles.body}>
                <TabList selectedValue={activeTab} onTabSelect={handleTabSelect}>
                    <Tooltip content={TOOLTIP_TAB_SCOPE} relationship="description" positioning="below" withArrow>
                        <Tab value="scope" icon={<Target20Regular />}>
                            {TAB_LABEL_SCOPE}
                        </Tab>
                    </Tooltip>
                    <Tooltip content={TOOLTIP_TAB_ENTITIES} relationship="description" positioning="below" withArrow>
                        <Tab value="entities" icon={<Table20Regular />}>
                            {TAB_LABEL_ENTITIES}
                        </Tab>
                    </Tooltip>
                    <Tooltip content={TOOLTIP_TAB_PCF_CONTROLS} relationship="description" positioning="below" withArrow>
                        <Tab value="pcfControls" icon={<Apps20Regular />}>
                            {TAB_LABEL_PCF_CONTROLS}
                        </Tab>
                    </Tooltip>
                </TabList>

                {activeTab === "scope" && (
                    <>
                        <Text>
                            <b>{LABEL_SELECTED_SOLUTION_ID}</b> {selectedSolutionId || NONE_TEXT}
                        </Text>
                        <Text>
                            <b>{LABEL_SELECTED_PUBLISHER_ID}</b> {selectedPublisherId || NONE_TEXT}
                        </Text>
                        <Text>
                            <b>{LABEL_SELECTED_BPF}</b> {selectedBpfName ?? NONE_TEXT}
                        </Text>
                    </>
                )}

                {activeTab === "entities" &&
                    (entityMetadataInfos.length === 0 ? (
                        <Text>
                            <b>{LABEL_ENTITIES_PREFIX}</b> {NONE_TEXT}
                        </Text>
                    ) : (
                        entityMetadataInfos.map((entityInfo) => {
                            const totalAttributes = entityInfo.attributes.length;
                            const totalPages = Math.max(1, Math.ceil(totalAttributes / ATTRIBUTES_PAGE_SIZE));
                            const page = Math.min(pageByEntity[entityInfo.logicalName] ?? 1, totalPages);
                            const pagedAttributes = entityInfo.attributes.slice(
                                (page - 1) * ATTRIBUTES_PAGE_SIZE,
                                page * ATTRIBUTES_PAGE_SIZE,
                            );

                            const setPage = (nextPage: number) =>
                                setPageByEntity((prev) => ({ ...prev, [entityInfo.logicalName]: nextPage }));

                            return (
                                <div key={entityInfo.logicalName}>
                                    <Divider>
                                        {entityInfo.displayName} ({entityInfo.logicalName})
                                    </Divider>
                                    <Text weight="semibold" block className={styles.entityLabel}>
                                        {entityInfo.displayName}
                                    </Text>
                                    <Table size="small">
                                        <TableHeader>
                                            <TableRow>
                                                <TableHeaderCell className={styles.tableHeaderCell}>
                                                    <Tooltip content={TOOLTIP_COLUMN_DISPLAY_NAME} relationship="description" positioning="below" withArrow>
                                                        <span>{COLUMN_LABEL_DISPLAY_NAME}</span>
                                                    </Tooltip>
                                                </TableHeaderCell>
                                                <TableHeaderCell className={styles.tableHeaderCell}>
                                                    <Tooltip content={TOOLTIP_COLUMN_LOGICAL_NAME} relationship="description" positioning="below" withArrow>
                                                        <span>{COLUMN_LABEL_LOGICAL_NAME}</span>
                                                    </Tooltip>
                                                </TableHeaderCell>
                                                <TableHeaderCell className={styles.tableHeaderCell}>
                                                    <Tooltip content={TOOLTIP_COLUMN_TYPE} relationship="description" positioning="below" withArrow>
                                                        <span>{COLUMN_LABEL_TYPE}</span>
                                                    </Tooltip>
                                                </TableHeaderCell>
                                                <TableHeaderCell className={styles.tableHeaderCell} />
                                            </TableRow>
                                        </TableHeader>
                                        <TableBody>
                                            {pagedAttributes.map((attribute) => (
                                                <TableRow key={attribute.logicalName}>
                                                    <TableCell>
                                                        <Link as="span">{attribute.displayName}</Link>
                                                    </TableCell>
                                                    <TableCell>{attribute.logicalName}</TableCell>
                                                    <TableCell>{attribute.attributeType}</TableCell>
                                                    <TableCell>
                                                        <Open20Regular />
                                                    </TableCell>
                                                </TableRow>
                                            ))}
                                        </TableBody>
                                    </Table>
                                    <div className={styles.pagingRow}>
                                        <Text size={200}>
                                            {totalAttributes} {ATTRIBUTE_WORD}
                                            {totalAttributes === 1 ? "" : "s"}
                                        </Text>
                                        <div className={styles.pagingControls}>
                                            <Button
                                                size="small"
                                                appearance="subtle"
                                                icon={<ChevronLeft20Regular />}
                                                disabled={page <= 1}
                                                onClick={() => setPage(page - 1)}
                                                aria-label={ARIA_LABEL_PREVIOUS_PAGE}
                                            />
                                            <Text size={200}>
                                                {PAGE_LABEL_PREFIX} {page} {PAGE_LABEL_SEPARATOR} {totalPages}
                                            </Text>
                                            <Button
                                                size="small"
                                                appearance="subtle"
                                                icon={<ChevronRight20Regular />}
                                                disabled={page >= totalPages}
                                                onClick={() => setPage(page + 1)}
                                                aria-label={ARIA_LABEL_NEXT_PAGE}
                                            />
                                        </div>
                                    </div>
                                </div>
                            );
                        })
                    ))}

                {activeTab === "pcfControls" &&
                    (totalPcfControls === 0 ? (
                        <Text>
                            <b>{LABEL_PCF_CONTROLS_PREFIX}</b> {NONE_TEXT}
                        </Text>
                    ) : (
                        <>
                            <Table size="small" className={styles.pcfControlsTable}>
                                <TableHeader>
                                    <TableRow>
                                        <TableHeaderCell
                                            className={mergeClasses(styles.tableHeaderCell, styles.nameHeaderCell)}
                                            sortable
                                            sortDirection={pcfControlSort?.column === "name" ? pcfControlSort.direction : undefined}
                                            onClick={() => togglePcfControlSort("name")}
                                        >
                                            <Tooltip content={TOOLTIP_COLUMN_NAME} relationship="description" positioning="below" withArrow>
                                                <span>{COLUMN_LABEL_NAME}</span>
                                            </Tooltip>
                                        </TableHeaderCell>
                                        <TableHeaderCell
                                            className={mergeClasses(styles.tableHeaderCell, styles.controlTypeHeaderCell)}
                                            sortable
                                            sortDirection={pcfControlSort?.column === "controlType" ? pcfControlSort.direction : undefined}
                                            onClick={() => togglePcfControlSort("controlType")}
                                        >
                                            <Tooltip content={TOOLTIP_COLUMN_CONTROL_TYPE} relationship="description" positioning="below" withArrow>
                                                <span>{COLUMN_LABEL_CONTROL_TYPE}</span>
                                            </Tooltip>
                                        </TableHeaderCell>
                                        <TableHeaderCell
                                            className={mergeClasses(styles.tableHeaderCell, styles.templateTypeHeaderCell)}
                                            sortable
                                            sortDirection={pcfControlSort?.column === "templateType" ? pcfControlSort.direction : undefined}
                                            onClick={() => togglePcfControlSort("templateType")}
                                        >
                                            <Tooltip content={TOOLTIP_COLUMN_TEMPLATE_TYPE} relationship="description" positioning="below" withArrow>
                                                <span>{COLUMN_LABEL_TEMPLATE_TYPE}</span>
                                            </Tooltip>
                                        </TableHeaderCell>
                                        <TableHeaderCell
                                            className={mergeClasses(styles.tableHeaderCell, styles.versionHeaderCell)}
                                            sortable
                                            sortDirection={pcfControlSort?.column === "version" ? pcfControlSort.direction : undefined}
                                            onClick={() => togglePcfControlSort("version")}
                                        >
                                            <Tooltip content={TOOLTIP_COLUMN_MANIFEST_VERSION} relationship="description" positioning="below" withArrow>
                                                <span>{COLUMN_LABEL_MANIFEST_VERSION}</span>
                                            </Tooltip>
                                        </TableHeaderCell>
                                        <TableHeaderCell
                                            className={styles.tableHeaderCell}
                                            sortable
                                            sortDirection={
                                                pcfControlSort?.column === "compatibleDataTypes" ? pcfControlSort.direction : undefined
                                            }
                                            onClick={() => togglePcfControlSort("compatibleDataTypes")}
                                        >
                                            <Tooltip content={TOOLTIP_COLUMN_COMPATIBLE_DATA_TYPES} relationship="description" positioning="below" withArrow>
                                                <span>{COLUMN_LABEL_COMPATIBLE_DATA_TYPES}</span>
                                            </Tooltip>
                                        </TableHeaderCell>
                                        <TableHeaderCell
                                            className={mergeClasses(styles.tableHeaderCell, styles.parametersHeaderCell)}
                                            sortable
                                            sortDirection={pcfControlSort?.column === "parameters" ? pcfControlSort.direction : undefined}
                                            onClick={() => togglePcfControlSort("parameters")}
                                        >
                                            <Tooltip content={TOOLTIP_COLUMN_PARAMETERS} relationship="description" positioning="below" withArrow>
                                                <span>{COLUMN_LABEL_PARAMETERS}</span>
                                            </Tooltip>
                                        </TableHeaderCell>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {pagedPcfControls.map((pcf) => (
                                        <TableRow key={pcf.id}>
                                            <TableCell>
                                                <Tooltip
                                                    content={pcf.controlName}
                                                    relationship="label"
                                                    positioning="below"
                                                    withArrow
                                                >
                                                    <Link as="span" className={styles.nameCell} onClick={() => handleOpenPcfDetails(pcf)}>
                                                        <Apps20Regular />
                                                        <span className={styles.nameText}>{pcf.controlName}</span>
                                                    </Link>
                                                </Tooltip>
                                            </TableCell>
                                            <TableCell>
                                                {pcf.isVirtual ? CONTROL_TYPE_VIRTUAL_LABEL : CONTROL_TYPE_STANDARD_LABEL}
                                            </TableCell>
                                            <TableCell>{pcf.templateType}</TableCell>
                                            <TableCell>{pcf.version || VERSION_UNKNOWN_LABEL}</TableCell>
                                            <TableCell>{pcf.compatibleDataTypes.join(", ") || NONE_TEXT}</TableCell>
                                            <TableCell>{pcf.parameters.length}</TableCell>
                                        </TableRow>
                                    ))}
                                </TableBody>
                            </Table>
                            <div className={styles.pagingRow}>
                                <Text size={200}>
                                    {totalPcfControls} {PCF_CONTROL_WORD}
                                    {totalPcfControls === 1 ? "" : "s"}
                                </Text>
                                <div className={styles.pagingControls}>
                                    <Button
                                        size="small"
                                        appearance="subtle"
                                        icon={<ChevronLeft20Regular />}
                                        disabled={currentPcfControlsPage <= 1}
                                        onClick={() => setPcfControlsPage(currentPcfControlsPage - 1)}
                                        aria-label={ARIA_LABEL_PREVIOUS_PAGE}
                                    />
                                    <Text size={200}>
                                        {PAGE_LABEL_PREFIX} {currentPcfControlsPage} {PAGE_LABEL_SEPARATOR} {totalPcfControlsPages}
                                    </Text>
                                    <Button
                                        size="small"
                                        appearance="subtle"
                                        icon={<ChevronRight20Regular />}
                                        disabled={currentPcfControlsPage >= totalPcfControlsPages}
                                        onClick={() => setPcfControlsPage(currentPcfControlsPage + 1)}
                                        aria-label={ARIA_LABEL_NEXT_PAGE}
                                    />
                                </div>
                            </div>
                        </>
                    ))}
            </DrawerBody>
        </OverlayDrawer>
            <PcfDetailsPanel open={isPcfDetailsOpen} onOpenChange={setIsPcfDetailsOpen} pcf={selectedPcfForDetails} />
        </>
    );
}
