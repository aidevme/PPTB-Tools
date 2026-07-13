import { useMemo, useState } from "react";
import {
    Badge,
    Button,
    DrawerBody,
    DrawerHeader,
    DrawerHeaderTitle,
    OverlayDrawer,
    SearchBox,
    Tab,
    TabList,
    Table,
    TableBody,
    TableCell,
    TableHeader,
    TableHeaderCell,
    TableRow,
    Text,
    ToggleButton,
    type BadgeProps,
    type SelectTabData,
    type SelectTabEvent,
} from "@fluentui/react-components";
import { Dismiss24Regular } from "@fluentui/react-icons";
import type { PcfControl, PcfParameter } from "../../services";
import { usePcfDetailsPanelStyles } from "../../styles";
import { GenericCard } from "../cards/GenericCard";
import { JsonFormatter } from "../jsonformatter/JsonFormatter";
import { XmlFormatter } from "../xmlformatter/XmlFormatter";
import { CATEGORY_COLORS, categorizePcfParameter } from "./pcfParameterCategory";
import { PropertyTypeDonut } from "./PropertyTypeDonut";

export interface IPcfDetailsPanelProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    /** The PCF control to show details for; the panel renders nothing (besides the closed drawer
     * shell) when this is `undefined`. */
    pcf: PcfControl | undefined;
}

type PcfDetailsTab = "properties" | "resources" | "features" | "manifest" | "clientJson";
type UsageFilter = "all" | "bound" | "input" | "output";

const CONTROL_TYPE_VIRTUAL_LABEL = "Virtual";
const CONTROL_TYPE_STANDARD_LABEL = "Standard";
const MANIFEST_VERSION_UNKNOWN_LABEL = "Unknown";

const USAGE_FILTERS: { value: UsageFilter; label: string }[] = [
    { value: "all", label: "All" },
    { value: "bound", label: "Bound" },
    { value: "input", label: "Input" },
    { value: "output", label: "Output" },
];

const USAGE_BADGE_COLOR: Record<string, BadgeProps["color"]> = {
    bound: "brand",
    input: "success",
    output: "informative",
};

/** Every control-level field, defaulted for a control with zero manifest parameters (nothing to
 * read `[0]` off of) so the rest of the component can destructure without repeating `?? ...`. */
const EMPTY_PARAMETER: Pick<
    PcfParameter,
    | "controlName"
    | "namespace"
    | "constructor"
    | "isVirtual"
    | "version"
    | "apiVersion"
    | "compatibleDataTypes"
    | "builtByName"
    | "builtByVersion"
    | "sharedTemplate"
    | "resources"
    | "externalDomains"
    | "typeGroups"
    | "featureUsage"
    | "rawManifestXml"
    | "rawClientJson"
> = {
    controlName: "",
    namespace: "",
    constructor: "",
    isVirtual: false,
    version: "",
    apiVersion: "",
    compatibleDataTypes: [],
    builtByName: "",
    builtByVersion: "",
    sharedTemplate: false,
    resources: [],
    externalDomains: [],
    typeGroups: [],
    featureUsage: [],
    rawManifestXml: "",
    rawClientJson: "",
};

/** Overlay drawer showing the full details of the PCF control currently selected in
 * `FormFactorsCard`: control facts, a property-type-mix chart, its manifest parameters (with
 * search/usage filtering), bundled resources, requested device/platform features, and the raw
 * manifest XML / clientjson. */
export function PcfDetailsPanel({ open, onOpenChange, pcf }: IPcfDetailsPanelProps) {
    const styles = usePcfDetailsPanelStyles();
    const [activeTab, setActiveTab] = useState<PcfDetailsTab>("properties");
    const [searchQuery, setSearchQuery] = useState("");
    const [usageFilter, setUsageFilter] = useState<UsageFilter>("all");

    const handleTabSelect = (_: SelectTabEvent, data: SelectTabData) => {
        setActiveTab(data.value as PcfDetailsTab);
    };

    const control = { ...EMPTY_PARAMETER, ...pcf?.parameters[0] };
    const parameters = pcf?.parameters ?? [];

    const filteredParameters = useMemo(() => {
        const query = searchQuery.trim().toLowerCase();
        return parameters.filter((param) => {
            const matchesUsage = usageFilter === "all" || param.usage === usageFilter;
            const matchesQuery =
                !query ||
                param.name.toLowerCase().includes(query) ||
                (param.ofType ?? "").toLowerCase().includes(query) ||
                (param.ofTypeGroup ?? "").toLowerCase().includes(query);
            return matchesUsage && matchesQuery;
        });
    }, [parameters, searchQuery, usageFilter]);

    return (
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
                    PCF Details
                </DrawerHeaderTitle>
            </DrawerHeader>
            <DrawerBody className={styles.body}>
                {!pcf ? (
                    <Text italic>No PCF control selected.</Text>
                ) : (
                    <>
                        <div className={styles.titleBlock}>
                            <Text size={200} weight="semibold" className={styles.eyebrow}>
                                PCF Control · {control.isVirtual ? CONTROL_TYPE_VIRTUAL_LABEL : CONTROL_TYPE_STANDARD_LABEL}
                            </Text>
                            <Text weight="bold" size={600}>
                                {control.constructor || control.controlName || "(unnamed control)"}
                            </Text>
                            <Text size={200} className={styles.mono}>
                                {control.controlName}
                            </Text>
                            <div className={styles.badgeRow}>
                                <Badge appearance="tint" color="brand">
                                    v{control.version || MANIFEST_VERSION_UNKNOWN_LABEL}
                                </Badge>
                                {control.apiVersion && (
                                    <Badge appearance="tint" color="informative">
                                        API {control.apiVersion}
                                    </Badge>
                                )}
                            </div>
                        </div>

                        <div className={styles.heroRow}>
                            <GenericCard title="Control facts" className={styles.heroCard}>
                                <div className={styles.factsGrid}>
                                    <Fact label="Namespace" value={control.namespace} mono />
                                    <Fact label="Constructor" value={control.constructor} mono />
                                    <Fact
                                        label="Control type"
                                        value={control.isVirtual ? CONTROL_TYPE_VIRTUAL_LABEL : CONTROL_TYPE_STANDARD_LABEL}
                                    />
                                    <Fact
                                        label="Compatible data types"
                                        value={control.compatibleDataTypes.length > 0 ? control.compatibleDataTypes.join(", ") : "(none)"}
                                    />
                                    {control.apiVersion && <Fact label="API version" value={control.apiVersion} />}
                                    {control.builtByName && (
                                        <Fact label="Built with" value={`${control.builtByName} cli ${control.builtByVersion}`} />
                                    )}
                                    <Fact label="Shared template" value={control.sharedTemplate ? "Enabled" : "Disabled"} />
                                    <Fact label="Custom control ID" value={pcf.id} mono small />
                                </div>
                            </GenericCard>

                            <GenericCard title="Property type mix" className={styles.heroCard}>
                                <PropertyTypeDonut key={pcf.id} parameters={parameters} typeGroups={control.typeGroups} />
                            </GenericCard>
                        </div>

                        <TabList selectedValue={activeTab} onTabSelect={handleTabSelect}>
                            <Tab value="properties">Properties ({parameters.length})</Tab>
                            <Tab value="resources">Resources ({control.resources.length})</Tab>
                            <Tab value="features">Feature usage ({control.featureUsage.length})</Tab>
                            <Tab value="manifest">Manifest XML</Tab>
                            <Tab value="clientJson">Client JSON</Tab>
                        </TabList>

                        {activeTab === "properties" && (
                            <>
                                <div className={styles.toolbar}>
                                    <SearchBox
                                        className={styles.search}
                                        placeholder="Search properties by name or type…"
                                        value={searchQuery}
                                        onChange={(_, data) => setSearchQuery(data.value)}
                                    />
                                    <div className={styles.filterRow}>
                                        {USAGE_FILTERS.map((filter) => (
                                            <ToggleButton
                                                key={filter.value}
                                                size="small"
                                                appearance="outline"
                                                checked={usageFilter === filter.value}
                                                onClick={() => setUsageFilter(filter.value)}
                                            >
                                                {filter.label}
                                            </ToggleButton>
                                        ))}
                                    </div>
                                </div>

                                {parameters.length === 0 ? (
                                    <Text italic>This control has no manifest parameters.</Text>
                                ) : filteredParameters.length === 0 ? (
                                    <Text italic>No properties match your filters.</Text>
                                ) : (
                                    <Table size="small">
                                        <TableHeader>
                                            <TableRow>
                                                <TableHeaderCell>Property</TableHeaderCell>
                                                <TableHeaderCell>Type</TableHeaderCell>
                                                <TableHeaderCell>Usage</TableHeaderCell>
                                                <TableHeaderCell>Required</TableHeaderCell>
                                            </TableRow>
                                        </TableHeader>
                                        <TableBody>
                                            {filteredParameters.map((param) => {
                                                const category = categorizePcfParameter(param, control.typeGroups);
                                                return (
                                                    <TableRow key={param.name}>
                                                        <TableCell className={styles.mono}>{param.name}</TableCell>
                                                        <TableCell>
                                                            <span className={styles.typeTag}>
                                                                <span
                                                                    className={styles.typeSwatch}
                                                                    style={{ background: CATEGORY_COLORS[category] }}
                                                                />
                                                                {param.ofTypeGroup ?? param.ofType ?? "—"}
                                                            </span>
                                                        </TableCell>
                                                        <TableCell>
                                                            <Badge appearance="tint" color={USAGE_BADGE_COLOR[param.usage] ?? "subtle"}>
                                                                {param.usage}
                                                            </Badge>
                                                        </TableCell>
                                                        <TableCell>
                                                            {param.required ? (
                                                                <Text weight="semibold" className={styles.requiredYes}>
                                                                    Required
                                                                </Text>
                                                            ) : (
                                                                <Text className={styles.requiredNo}>Optional</Text>
                                                            )}
                                                        </TableCell>
                                                    </TableRow>
                                                );
                                            })}
                                        </TableBody>
                                    </Table>
                                )}
                            </>
                        )}

                        {activeTab === "resources" && (
                            <div className={styles.resourceGrid}>
                                <GenericCard title="Bundled resources">
                                    {control.resources.length === 0 ? (
                                        <Text italic>No bundled resources.</Text>
                                    ) : (
                                        control.resources.map((resource, index) => (
                                            <div key={`${resource.kind}-${index}`} className={styles.listRow}>
                                                <span className={styles.listIcon}>{resource.kind.toUpperCase().slice(0, 3)}</span>
                                                <div>
                                                    <Text block className={styles.listTitle}>
                                                        {resource.path}
                                                    </Text>
                                                    <Text block className={styles.listSub}>
                                                        {resource.version
                                                            ? `v${resource.version}`
                                                            : `order ${resource.order ?? "—"} · ${resource.kind} resource`}
                                                    </Text>
                                                </div>
                                            </div>
                                        ))
                                    )}
                                </GenericCard>

                                <GenericCard title="Allowed external domains">
                                    {control.externalDomains.length === 0 ? (
                                        <Text italic>No external domains declared.</Text>
                                    ) : (
                                        control.externalDomains.map((domain) => (
                                            <Text key={domain} block className={styles.mono}>
                                                {domain}
                                            </Text>
                                        ))
                                    )}

                                    <Text weight="semibold" block className={styles.sectionTitle}>
                                        Type groups
                                    </Text>
                                    {control.typeGroups.length === 0 ? (
                                        <Text italic>No type groups declared.</Text>
                                    ) : (
                                        control.typeGroups.map((group) => (
                                            <div key={group.name} className={styles.listRow}>
                                                <div>
                                                    <Text block className={styles.listTitle}>
                                                        {group.name}
                                                    </Text>
                                                    <Text block className={styles.listSub}>
                                                        {group.types.join(", ") || "(no member types)"}
                                                    </Text>
                                                </div>
                                            </div>
                                        ))
                                    )}
                                </GenericCard>
                            </div>
                        )}

                        {activeTab === "features" && (
                            <GenericCard title="Requested device & platform capabilities">
                                {control.featureUsage.length === 0 ? (
                                    <Text italic>This control declares no feature usage.</Text>
                                ) : (
                                    <div className={styles.chipCloud}>
                                        {control.featureUsage.map((feature) => (
                                            <div key={feature.name} className={styles.featureChip}>
                                                {feature.name}
                                                <Badge
                                                    size="tiny"
                                                    appearance="tint"
                                                    color={feature.required ? "success" : "subtle"}
                                                >
                                                    {feature.required ? "Required" : "Optional"}
                                                </Badge>
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </GenericCard>
                        )}

                        {activeTab === "manifest" && (
                            <XmlFormatter
                                xml={control.rawManifestXml}
                                theme="light"
                                prettyPrint
                                placeholder="No manifest data available."
                            />
                        )}

                        {activeTab === "clientJson" && (
                            <JsonFormatter value={control.rawClientJson} theme="light" placeholder="No client json data available." />
                        )}
                    </>
                )}
            </DrawerBody>
        </OverlayDrawer>
    );
}

interface IFactProps {
    label: string;
    value: string;
    mono?: boolean;
    small?: boolean;
}

/** One label/value pair in the "Control facts" card's grid. */
function Fact({ label, value, mono, small }: IFactProps) {
    const styles = usePcfDetailsPanelStyles();
    return (
        <div>
            <Text block size={200} className={styles.factLabel}>
                {label}
            </Text>
            <Text block weight="semibold" size={small ? 200 : 300} className={mono ? styles.mono : undefined}>
                {value || "—"}
            </Text>
        </div>
    );
}
