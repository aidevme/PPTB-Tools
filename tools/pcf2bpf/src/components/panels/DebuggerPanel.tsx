import { useState } from "react";
import {
    Button,
    Divider,
    DrawerBody,
    DrawerHeader,
    DrawerHeaderTitle,
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
    type SelectTabData,
    type SelectTabEvent,
} from "@fluentui/react-components";
import { ChevronLeft20Regular, ChevronRight20Regular, Dismiss24Regular } from "@fluentui/react-icons";
import { useToolContext } from "../../services/pptbtoolservice";
import { useDebuggerPanelStyles } from "../../styles";

export interface IDebuggerPanelProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

type DebuggerTab = "scope" | "entities";

/** Max attribute rows shown per page in each entity's attribute table. */
const ATTRIBUTES_PAGE_SIZE = 20;

/** Overlay drawer for in-app debugging tools, opened from the `Footer`'s "Debugger" button. */
export function DebuggerPanel({ open, onOpenChange }: IDebuggerPanelProps) {
    const styles = useDebuggerPanelStyles();
    const { bpfProcesses, selectedBpfId, selectedSolutionId, selectedPublisherId, entityMetadataInfos } = useToolContext();
    const selectedBpfName = bpfProcesses.find((b) => b.workflowid === selectedBpfId)?.name;
    const [activeTab, setActiveTab] = useState<DebuggerTab>("scope");
    const [pageByEntity, setPageByEntity] = useState<Record<string, number>>({});

    const handleTabSelect = (_: SelectTabEvent, data: SelectTabData) => {
        setActiveTab(data.value as DebuggerTab);
    };

    return (
        <OverlayDrawer position="end" size="large" open={open} onOpenChange={(_, data) => onOpenChange(data.open)}>
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
                    <Tab value="scope">Scope</Tab>
                    <Tab value="entities">BPF Entities &amp; Attributes</Tab>
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
                                                <TableHeaderCell>Display Name</TableHeaderCell>
                                                <TableHeaderCell>Logical Name</TableHeaderCell>
                                                <TableHeaderCell>Type</TableHeaderCell>
                                            </TableRow>
                                        </TableHeader>
                                        <TableBody>
                                            {pagedAttributes.map((attribute) => (
                                                <TableRow key={attribute.logicalName}>
                                                    <TableCell>{attribute.displayName}</TableCell>
                                                    <TableCell>{attribute.logicalName}</TableCell>
                                                    <TableCell>{attribute.attributeType}</TableCell>
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
            </DrawerBody>
        </OverlayDrawer>
    );
}
