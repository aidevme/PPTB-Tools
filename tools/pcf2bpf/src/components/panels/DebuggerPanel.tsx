import { useState } from "react";
import {
    Button,
    Divider,
    DrawerBody,
    DrawerHeader,
    DrawerHeaderTitle,
    Link,
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
import type { PcfControl } from "../../services";
import { useToolContext } from "../../services/pptbtoolservice";
import { useDebuggerPanelStyles } from "../../styles";
import { PcfDetailsPanel } from "./PcfDetailsPanel";

export interface IDebuggerPanelProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

type DebuggerTab = "scope" | "entities" | "pcfControls";

/** Max attribute rows shown per page in each entity's attribute table, and max PCF control rows
 * shown per page in the "PCF Controls" tab. */
const ATTRIBUTES_PAGE_SIZE = 20;

const CONTROL_TYPE_VIRTUAL_LABEL = "Virtual";
const CONTROL_TYPE_STANDARD_LABEL = "Standard";

type PcfControlSortColumn = "name" | "controlType" | "version" | "compatibleDataTypes" | "parameters";

const PCF_CONTROL_SORT_VALUE: Record<PcfControlSortColumn, (pcf: PcfControl) => string | number> = {
    name: (pcf) => (pcf.parameters[0]?.controlName ?? "").toLowerCase(),
    controlType: (pcf) => (pcf.parameters[0]?.isVirtual ? CONTROL_TYPE_VIRTUAL_LABEL : CONTROL_TYPE_STANDARD_LABEL),
    version: (pcf) => (pcf.parameters[0]?.version ?? "").toLowerCase(),
    compatibleDataTypes: (pcf) => (pcf.parameters[0]?.compatibleDataTypes ?? []).join(", ").toLowerCase(),
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
                            aria-label="Close"
                            icon={<Dismiss24Regular />}
                            onClick={() => onOpenChange(false)}
                        />
                    }
                >
                    Debugger
                </DrawerHeaderTitle>
            </DrawerHeader>
            <DrawerBody className={styles.body}>
                <TabList selectedValue={activeTab} onTabSelect={handleTabSelect}>
                    <Tooltip
                        content="Currently selected solution, publisher, and Business Process Flow."
                        relationship="description"
                        positioning="below"
                        withArrow
                    >
                        <Tab value="scope" icon={<Target20Regular />}>
                            Scope
                        </Tab>
                    </Tooltip>
                    <Tooltip
                        content="Entities and attributes resolved for the selected Business Process Flow."
                        relationship="description"
                        positioning="below"
                        withArrow
                    >
                        <Tab value="entities" icon={<Table20Regular />}>
                            BPF Entities &amp; Attributes
                        </Tab>
                    </Tooltip>
                    <Tooltip
                        content="Every registered PCF control and its manifest parameters."
                        relationship="description"
                        positioning="below"
                        withArrow
                    >
                        <Tab value="pcfControls" icon={<Apps20Regular />}>
                            PCF Controls
                        </Tab>
                    </Tooltip>
                </TabList>

                {activeTab === "scope" && (
                    <>
                        <Text>
                            <b>Selected Solution Id:</b> {selectedSolutionId || "(none)"}
                        </Text>
                        <Text>
                            <b>Selected Publisher Id:</b> {selectedPublisherId || "(none)"}
                        </Text>
                        <Text>
                            <b>Selected BPF:</b> {selectedBpfName ?? "(none)"}
                        </Text>
                    </>
                )}

                {activeTab === "entities" &&
                    (entityMetadataInfos.length === 0 ? (
                        <Text>
                            <b>Entities:</b> (none)
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
                                                    <Tooltip content="The attribute's display name." relationship="description" positioning="below" withArrow>
                                                        <span>Display Name</span>
                                                    </Tooltip>
                                                </TableHeaderCell>
                                                <TableHeaderCell className={styles.tableHeaderCell}>
                                                    <Tooltip content="The attribute's Dataverse logical name." relationship="description" positioning="below" withArrow>
                                                        <span>Logical Name</span>
                                                    </Tooltip>
                                                </TableHeaderCell>
                                                <TableHeaderCell className={styles.tableHeaderCell}>
                                                    <Tooltip content="The attribute's Dataverse AttributeType." relationship="description" positioning="below" withArrow>
                                                        <span>Type</span>
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
                                            {totalAttributes} attribute{totalAttributes === 1 ? "" : "s"}
                                        </Text>
                                        <div className={styles.pagingControls}>
                                            <Button
                                                size="small"
                                                appearance="subtle"
                                                icon={<ChevronLeft20Regular />}
                                                disabled={page <= 1}
                                                onClick={() => setPage(page - 1)}
                                                aria-label="Previous page"
                                            />
                                            <Text size={200}>
                                                Page {page} of {totalPages}
                                            </Text>
                                            <Button
                                                size="small"
                                                appearance="subtle"
                                                icon={<ChevronRight20Regular />}
                                                disabled={page >= totalPages}
                                                onClick={() => setPage(page + 1)}
                                                aria-label="Next page"
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
                            <b>PCF Controls:</b> (none)
                        </Text>
                    ) : (
                        <>
                            <Table size="small">
                                <TableHeader>
                                    <TableRow>
                                        <TableHeaderCell
                                            className={styles.tableHeaderCell}
                                            sortable
                                            sortDirection={pcfControlSort?.column === "name" ? pcfControlSort.direction : undefined}
                                            onClick={() => togglePcfControlSort("name")}
                                        >
                                            <Tooltip content="The registered PCF control's fully-qualified name." relationship="description" positioning="below" withArrow>
                                                <span>Name</span>
                                            </Tooltip>
                                        </TableHeaderCell>
                                        <TableHeaderCell
                                            className={styles.tableHeaderCell}
                                            sortable
                                            sortDirection={pcfControlSort?.column === "controlType" ? pcfControlSort.direction : undefined}
                                            onClick={() => togglePcfControlSort("controlType")}
                                        >
                                            <Tooltip content="Virtual (React-rendered) or Standard (HTML)." relationship="description" positioning="below" withArrow>
                                                <span>Control Type</span>
                                            </Tooltip>
                                        </TableHeaderCell>
                                        <TableHeaderCell
                                            className={styles.tableHeaderCell}
                                            sortable
                                            sortDirection={pcfControlSort?.column === "version" ? pcfControlSort.direction : undefined}
                                            onClick={() => togglePcfControlSort("version")}
                                        >
                                            <Tooltip content="The PCF manifest schema version the control was built against." relationship="description" positioning="below" withArrow>
                                                <span>Manifest Version</span>
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
                                            <Tooltip content="Dataverse attribute types this control can be assigned to." relationship="description" positioning="below" withArrow>
                                                <span>Compatible Data Types</span>
                                            </Tooltip>
                                        </TableHeaderCell>
                                        <TableHeaderCell
                                            className={styles.tableHeaderCell}
                                            sortable
                                            sortDirection={pcfControlSort?.column === "parameters" ? pcfControlSort.direction : undefined}
                                            onClick={() => togglePcfControlSort("parameters")}
                                        >
                                            <Tooltip content="Number of manifest parameters this control declares." relationship="description" positioning="below" withArrow>
                                                <span>Parameters</span>
                                            </Tooltip>
                                        </TableHeaderCell>
                                        <TableHeaderCell className={styles.tableHeaderCell} />
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {pagedPcfControls.map((pcf) => (
                                        <TableRow key={pcf.id}>
                                            <TableCell>
                                                <Link as="span">{pcf.parameters[0]?.controlName ?? ""}</Link>
                                            </TableCell>
                                            <TableCell>
                                                {pcf.parameters[0]?.isVirtual ? CONTROL_TYPE_VIRTUAL_LABEL : CONTROL_TYPE_STANDARD_LABEL}
                                            </TableCell>
                                            <TableCell>{pcf.parameters[0]?.version || "Unknown"}</TableCell>
                                            <TableCell>{(pcf.parameters[0]?.compatibleDataTypes ?? []).join(", ") || "(none)"}</TableCell>
                                            <TableCell>{pcf.parameters.length}</TableCell>
                                            <TableCell>
                                                <Button
                                                    appearance="subtle"
                                                    size="small"
                                                    icon={<Open20Regular />}
                                                    aria-label="View PCF control details"
                                                    onClick={() => handleOpenPcfDetails(pcf)}
                                                />
                                            </TableCell>
                                        </TableRow>
                                    ))}
                                </TableBody>
                            </Table>
                            <div className={styles.pagingRow}>
                                <Text size={200}>
                                    {totalPcfControls} PCF control{totalPcfControls === 1 ? "" : "s"}
                                </Text>
                                <div className={styles.pagingControls}>
                                    <Button
                                        size="small"
                                        appearance="subtle"
                                        icon={<ChevronLeft20Regular />}
                                        disabled={currentPcfControlsPage <= 1}
                                        onClick={() => setPcfControlsPage(currentPcfControlsPage - 1)}
                                        aria-label="Previous page"
                                    />
                                    <Text size={200}>
                                        Page {currentPcfControlsPage} of {totalPcfControlsPages}
                                    </Text>
                                    <Button
                                        size="small"
                                        appearance="subtle"
                                        icon={<ChevronRight20Regular />}
                                        disabled={currentPcfControlsPage >= totalPcfControlsPages}
                                        onClick={() => setPcfControlsPage(currentPcfControlsPage + 1)}
                                        aria-label="Next page"
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
