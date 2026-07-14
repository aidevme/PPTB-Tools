import { useMemo, useState } from "react";
import {
    Badge,
    Button,
    DrawerBody,
    DrawerHeader,
    DrawerHeaderTitle,
    Link,
    OverlayDrawer,
    Popover,
    PopoverSurface,
    PopoverTrigger,
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
    Tooltip,
    type BadgeProps,
    type SelectTabData,
    type SelectTabEvent,
} from "@fluentui/react-components";
import { Dismiss24Regular } from "@fluentui/react-icons";
import type { PcfControl } from "../../services";
import { usePcfDetailsPanelStyles } from "../../styles";
import { GenericCard } from "../cards/GenericCard";
import { JsonFormatter } from "../formatters/jsonformatter/JsonFormatter";
import { XmlFormatter } from "../formatters/xmlformatter/XmlFormatter";
import { CATEGORY_COLORS, categorizePcfParameter, categorizeTypeName } from "./pcfParameterCategory";
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
                                PCF Control · {pcf.isVirtual ? CONTROL_TYPE_VIRTUAL_LABEL : CONTROL_TYPE_STANDARD_LABEL}
                            </Text>
                            <Text weight="bold" size={600}>
                                {pcf.constructor || pcf.controlName || "(unnamed control)"}
                            </Text>
                            <Text size={200} className={styles.mono}>
                                {pcf.controlName}
                            </Text>
                            <div className={styles.badgeRow}>
                                <Badge appearance="tint" color="brand">
                                    v{pcf.version || MANIFEST_VERSION_UNKNOWN_LABEL}
                                </Badge>
                                {pcf.apiVersion && (
                                    <Badge appearance="tint" color="informative">
                                        API {pcf.apiVersion}
                                    </Badge>
                                )}
                            </div>
                        </div>

                        <div className={styles.heroRow}>
                            <GenericCard title="Control facts" className={styles.heroCard}>
                                <div className={styles.factsGrid}>
                                    <Fact label="Namespace" value={pcf.namespace} mono />
                                    <Fact label="Constructor" value={pcf.constructor} mono />
                                    <Fact
                                        label="Control type"
                                        value={pcf.isVirtual ? CONTROL_TYPE_VIRTUAL_LABEL : CONTROL_TYPE_STANDARD_LABEL}
                                    />
                                    <Fact label="Template type" value={pcf.templateType} />
                                    <Fact
                                        label="Compatible data types"
                                        value={pcf.compatibleDataTypes.length > 0 ? pcf.compatibleDataTypes.join(", ") : "(none)"}
                                    />
                                    {pcf.apiVersion && <Fact label="API version" value={pcf.apiVersion} />}
                                    {pcf.builtByName && (
                                        <Fact label="Built with" value={`${pcf.builtByName} cli ${pcf.builtByVersion}`} />
                                    )}
                                    <Fact label="Shared template" value={pcf.sharedTemplate ? "Enabled" : "Disabled"} />
                                    <Fact label="Custom control ID" value={pcf.id} mono small />
                                </div>
                            </GenericCard>

                            <GenericCard title="Property type mix" className={styles.heroCard}>
                                <PropertyTypeDonut key={pcf.id} parameters={parameters} typeGroups={pcf.typeGroups} />
                            </GenericCard>
                        </div>

                        <TabList selectedValue={activeTab} onTabSelect={handleTabSelect}>
                            <Tab value="properties">Properties ({parameters.length})</Tab>
                            <Tab value="resources">Resources ({pcf.resources.length})</Tab>
                            <Tab value="features">Feature usage ({pcf.featureUsage.length})</Tab>
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
                                                <TableHeaderCell className={styles.tableHeaderCell}>
                                                    <Tooltip
                                                        content="The manifest parameter's name."
                                                        relationship="description"
                                                        positioning="below"
                                                        withArrow
                                                    >
                                                        <span>Property</span>
                                                    </Tooltip>
                                                </TableHeaderCell>
                                                <TableHeaderCell className={styles.tableHeaderCell}>
                                                    <Tooltip
                                                        content="The Dataverse attribute type (or type group) this parameter accepts."
                                                        relationship="description"
                                                        positioning="below"
                                                        withArrow
                                                    >
                                                        <span>Type</span>
                                                    </Tooltip>
                                                </TableHeaderCell>
                                                <TableHeaderCell className={styles.tableHeaderCell}>
                                                    <Tooltip
                                                        content="Bound parameters are wired to the field itself; input/output parameters are user-configurable."
                                                        relationship="description"
                                                        positioning="below"
                                                        withArrow
                                                    >
                                                        <span>Usage</span>
                                                    </Tooltip>
                                                </TableHeaderCell>
                                                <TableHeaderCell className={styles.tableHeaderCell}>
                                                    <Tooltip
                                                        content="Whether the manifest declares this parameter as required."
                                                        relationship="description"
                                                        positioning="below"
                                                        withArrow
                                                    >
                                                        <span>Required</span>
                                                    </Tooltip>
                                                </TableHeaderCell>
                                            </TableRow>
                                        </TableHeader>
                                        <TableBody>
                                            {filteredParameters.map((param) => {
                                                const category = categorizePcfParameter(param, pcf.typeGroups);
                                                const typeGroup = param.ofTypeGroup
                                                    ? pcf.typeGroups.find((g) => g.name === param.ofTypeGroup)
                                                    : undefined;
                                                return (
                                                    <TableRow key={param.name}>
                                                        <TableCell className={styles.mono}>{param.name}</TableCell>
                                                        <TableCell>
                                                            {param.ofTypeGroup ? (
                                                                <Popover withArrow>
                                                                    <PopoverTrigger disableButtonEnhancement>
                                                                        <Link as="span" className={styles.typeTag}>
                                                                            <span
                                                                                className={styles.typeSwatch}
                                                                                style={{ background: CATEGORY_COLORS[category] }}
                                                                            />
                                                                            {param.ofTypeGroup} (Type Group)
                                                                        </Link>
                                                                    </PopoverTrigger>
                                                                    <PopoverSurface className={styles.typeGroupPopover}>
                                                                        <Text weight="semibold" block>
                                                                            {param.ofTypeGroup}
                                                                        </Text>
                                                                        {typeGroup?.types.length ? (
                                                                            typeGroup.types.map((type) => (
                                                                                <span key={type} className={styles.typeTag}>
                                                                                    <span
                                                                                        className={styles.typeSwatch}
                                                                                        style={{
                                                                                            background: CATEGORY_COLORS[categorizeTypeName(type)],
                                                                                        }}
                                                                                    />
                                                                                    <Text className={styles.mono}>{type}</Text>
                                                                                </span>
                                                                            ))
                                                                        ) : (
                                                                            <Text italic>No member types declared.</Text>
                                                                        )}
                                                                    </PopoverSurface>
                                                                </Popover>
                                                            ) : (
                                                                <span className={styles.typeTag}>
                                                                    <span
                                                                        className={styles.typeSwatch}
                                                                        style={{ background: CATEGORY_COLORS[category] }}
                                                                    />
                                                                    {param.ofType ?? "—"}
                                                                </span>
                                                            )}
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
                                    {pcf.resources.length === 0 ? (
                                        <Text italic>No bundled resources.</Text>
                                    ) : (
                                        pcf.resources.map((resource, index) => (
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
                                    {pcf.externalDomains.length === 0 ? (
                                        <Text italic>No external domains declared.</Text>
                                    ) : (
                                        pcf.externalDomains.map((domain) => (
                                            <Text key={domain} block className={styles.mono}>
                                                {domain}
                                            </Text>
                                        ))
                                    )}

                                    <Text weight="semibold" block className={styles.sectionTitle}>
                                        Type groups
                                    </Text>
                                    {pcf.typeGroups.length === 0 ? (
                                        <Text italic>No type groups declared.</Text>
                                    ) : (
                                        pcf.typeGroups.map((group) => (
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
                                {pcf.featureUsage.length === 0 ? (
                                    <Text italic>This control declares no feature usage.</Text>
                                ) : (
                                    <div className={styles.chipCloud}>
                                        {pcf.featureUsage.map((feature) => (
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
                                xml={pcf.rawManifestXml}
                                theme="light"
                                prettyPrint
                                placeholder="No manifest data available."
                            />
                        )}

                        {activeTab === "clientJson" && (
                            <JsonFormatter value={pcf.rawClientJson} theme="light" placeholder="No client json data available." />
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
