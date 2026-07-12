import { useState } from "react";
import {
    Button,
    DrawerBody,
    DrawerHeader,
    DrawerHeaderTitle,
    Field,
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
    Textarea,
    type SelectTabData,
    type SelectTabEvent,
} from "@fluentui/react-components";
import { Dismiss24Regular } from "@fluentui/react-icons";
import type { PcfControl } from "../../services";
import { usePcfDetailsPanelStyles } from "../../styles";

export interface IPcfDetailsPanelProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    /** The PCF control to show details for; the panel renders nothing (besides the closed drawer
     * shell) when this is `undefined`. */
    pcf: PcfControl | undefined;
}

type PcfDetailsTab = "controlDetails" | "rawData";

const CONTROL_TYPE_VIRTUAL_LABEL = "Virtual";
const CONTROL_TYPE_STANDARD_LABEL = "Standard";
const MANIFEST_VERSION_UNKNOWN_LABEL = "Unknown";

/** Overlay drawer showing the full details (control type, manifest version, compatible data types,
 * and manifest parameters) of the PCF control currently selected in `FormFactorsCard`. */
export function PcfDetailsPanel({ open, onOpenChange, pcf }: IPcfDetailsPanelProps) {
    const styles = usePcfDetailsPanelStyles();
    const [activeTab, setActiveTab] = useState<PcfDetailsTab>("controlDetails");

    const handleTabSelect = (_: SelectTabEvent, data: SelectTabData) => {
        setActiveTab(data.value as PcfDetailsTab);
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
                    PCF Details
                </DrawerHeaderTitle>
            </DrawerHeader>
            <DrawerBody className={styles.body}>
                {!pcf ? (
                    <Text italic>No PCF control selected.</Text>
                ) : (
                    <>
                        <Text weight="semibold" size={500}>
                            {pcf.name}
                        </Text>

                        <TabList selectedValue={activeTab} onTabSelect={handleTabSelect}>
                            <Tab value="controlDetails">Control Details</Tab>
                            <Tab value="rawData">Raw Data</Tab>
                        </TabList>

                        {activeTab === "controlDetails" && (
                            <>
                                <div className={styles.row}>
                                    <Text weight="semibold">Control Name</Text>
                                    <Text>{pcf.name}</Text>
                                </div>
                                <div className={styles.row}>
                                    <Text weight="semibold">Control type</Text>
                                    <Text>{pcf.isVirtual ? CONTROL_TYPE_VIRTUAL_LABEL : CONTROL_TYPE_STANDARD_LABEL}</Text>
                                </div>
                                <div className={styles.row}>
                                    <Text weight="semibold">Manifest version</Text>
                                    <Text>{pcf.version || MANIFEST_VERSION_UNKNOWN_LABEL}</Text>
                                </div>
                                <div className={styles.row}>
                                    <Text weight="semibold">Compatible data types</Text>
                                    <Text>{pcf.compatibleDataTypes.length > 0 ? pcf.compatibleDataTypes.join(", ") : "(none)"}</Text>
                                </div>

                                <Text weight="semibold" block className={styles.parametersLabel}>
                                    Parameters
                                </Text>
                                {pcf.parameters.length === 0 ? (
                                    <Text italic>This control has no manifest parameters.</Text>
                                ) : (
                                    <Table size="small">
                                        <TableHeader>
                                            <TableRow>
                                                <TableHeaderCell>Name</TableHeaderCell>
                                                <TableHeaderCell>Usage</TableHeaderCell>
                                                <TableHeaderCell>Required?</TableHeaderCell>
                                                <TableHeaderCell>Type</TableHeaderCell>
                                            </TableRow>
                                        </TableHeader>
                                        <TableBody>
                                            {pcf.parameters.map((param) => (
                                                <TableRow key={param.name}>
                                                    <TableCell>{param.name}</TableCell>
                                                    <TableCell>{param.usage}</TableCell>
                                                    <TableCell>{param.required ? "Yes" : "No"}</TableCell>
                                                    <TableCell>{param.ofTypeGroup ?? param.ofType ?? "—"}</TableCell>
                                                </TableRow>
                                            ))}
                                        </TableBody>
                                    </Table>
                                )}
                            </>
                        )}

                        {activeTab === "rawData" && (
                            <>
                                <Field label="Raw Manifest">
                                    <Textarea
                                        className={styles.rawTextarea}
                                        textarea={{ className: styles.rawTextareaField }}
                                        value={pcf.rawManifestXml}
                                        readOnly
                                        resize="vertical"
                                    />
                                </Field>

                                <Field label="Raw Client Json">
                                    <Textarea
                                        className={styles.rawTextarea}
                                        textarea={{ className: styles.rawTextareaField }}
                                        value={pcf.rawClientJson}
                                        readOnly
                                        resize="vertical"
                                    />
                                </Field>
                            </>
                        )}
                    </>
                )}
            </DrawerBody>
        </OverlayDrawer>
    );
}
