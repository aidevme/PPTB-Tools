import { useMemo, useState, type Dispatch, type SetStateAction } from "react";
import {
    Checkbox,
    Dropdown,
    Input,
    Link,
    mergeClasses,
    Option,
    Table,
    TableBody,
    TableCell,
    TableHeader,
    TableHeaderCell,
    TableRow,
    Tooltip,
    type SortDirection,
} from "@fluentui/react-components";
import { ArrowExport20Regular, ArrowImport20Regular, PlugConnected20Regular } from "@fluentui/react-icons";
import type { PcfControl, PcfParameter } from "../../services";
import { useToolContext } from "../../services/pptbtoolcontextservice";
import { usePcfConfiguratorTableStyles } from "../../styles";

// Placeholder field choices for the "bind to field" Dropdown shown when "Is Static?" is unchecked,
// for non-Lookup parameter types. Not wired to real entity metadata yet — field-binding itself isn't
// implemented in this port. Lookup-typed parameters use real lookup fields instead (see `LOOKUP_ATTRIBUTE_TYPES`).
const MOCK_BIND_FIELD_OPTIONS = ["fullname", "emailaddress1", "telephone1", "address1_city", "parentcustomerid"];

/** Dataverse `AttributeType` values that represent a lookup field, mirroring `dataverse.ts`'s
 * `ATTRIBUTE_TYPE_TO_PCF_TYPES` mapping to `Lookup.Simple`/`Lookup.Customer`/`Lookup.Owner`. */
const LOOKUP_ATTRIBUTE_TYPES = new Set(["Lookup", "Customer", "Owner"]);

/** Dataverse `AttributeType` value for a simple (single-select) choice field. Excludes
 * `MultiSelectPicklist` (not "simple") and the reserved `State`/`Status` choice fields. */
const CHOICE_FIELD_ATTRIBUTE_TYPES = new Set(["Picklist"]);

/** Dataverse `AttributeType` value for single-line text fields — covers every `SingleLine.*` PCF
 * of-type (Text/Email/Phone/URL/Ticker/TextArea), since Dataverse metadata doesn't distinguish them
 * by `AttributeType`, only by format. */
const SINGLE_LINE_TEXT_ATTRIBUTE_TYPES = new Set(["String"]);

/** Icon shown next to a parameter's usage in the parameter table. */
const PARAM_USAGE_ICONS: Record<string, JSX.Element> = {
    bound: <PlugConnected20Regular />,
    input: <ArrowImport20Regular />,
    output: <ArrowExport20Regular />,
};

/** Sortable columns of the parameter table — every column except "Param Value". */
type ParamSortColumn = "name" | "usage" | "required" | "type" | "isStatic";

/** Comparable value extracted per {@link ParamSortColumn}; "isStatic" is constant (always static here). */
const PARAM_SORT_VALUE: Record<ParamSortColumn, (param: PcfParameter) => string | number> = {
    name: (param) => param.name.toLowerCase(),
    usage: (param) => param.usage.toLowerCase(),
    required: (param) => (param.required ? 1 : 0),
    type: (param) => (param.ofTypeGroup ?? param.ofType ?? "").toLowerCase(),
    isStatic: () => 1,
};

function sortParams(params: PcfParameter[], column: ParamSortColumn | null, direction: SortDirection): PcfParameter[] {
    if (!column) return params;

    const getValue = PARAM_SORT_VALUE[column];
    const factor = direction === "ascending" ? 1 : -1;

    return [...params].sort((a, b) => {
        const valueA = getValue(a);
        const valueB = getValue(b);
        if (valueA < valueB) return -1 * factor;
        if (valueA > valueB) return 1 * factor;
        return 0;
    });
}

export interface IPcfConfiguratorTableProps {
    selectedPcf: PcfControl | undefined;
    formFactorId?: string;
    /** Logical name of the entity the current field belongs to, used to look up its lookup-typed and
     * simple-choice-typed fields (from `ToolContext`'s `entityMetadataInfos`) for Lookup/OptionSet-typed
     * parameters' bind-field Dropdown. */
    entityLogicalName: string;
    paramValues: Record<string, string>;
    onParamValuesChange: Dispatch<SetStateAction<Record<string, string>>>;
    /** "Is Static?" per non-Enum parameter; Enum parameters are always static regardless of this map.
     * Toggling has no effect yet — this port doesn't support binding a parameter to a field. Owned by
     * the parent so it can be reset alongside `paramValues` on the same field/form-factor/PCF changes. */
    staticOverrides: Record<string, boolean>;
    onStaticOverridesChange: Dispatch<SetStateAction<Record<string, boolean>>>;
}

/** Sortable parameter table for the currently selected PCF control's manifest parameters. */
export function PcfConfiguratorTable({
    selectedPcf,
    entityLogicalName,
    paramValues,
    onParamValuesChange,
    staticOverrides,
    onStaticOverridesChange,
}: IPcfConfiguratorTableProps) {
    const styles = usePcfConfiguratorTableStyles();
    const { entityMetadataInfos } = useToolContext();
    const [paramSort, setParamSort] = useState<{ column: ParamSortColumn; direction: SortDirection } | null>(null);

    const entityInfo = useMemo(
        () => entityMetadataInfos.find((e) => e.logicalName === entityLogicalName),
        [entityMetadataInfos, entityLogicalName],
    );

    const lookupFieldOptions = useMemo(
        () => (entityInfo?.attributes ?? []).filter((a) => LOOKUP_ATTRIBUTE_TYPES.has(a.attributeType)).map((a) => a.logicalName),
        [entityInfo],
    );

    const choiceFieldOptions = useMemo(
        () => (entityInfo?.attributes ?? []).filter((a) => CHOICE_FIELD_ATTRIBUTE_TYPES.has(a.attributeType)).map((a) => a.logicalName),
        [entityInfo],
    );

    const textFieldOptions = useMemo(
        () => (entityInfo?.attributes ?? []).filter((a) => SINGLE_LINE_TEXT_ATTRIBUTE_TYPES.has(a.attributeType)).map((a) => a.logicalName),
        [entityInfo],
    );

    const toggleParamSort = (column: ParamSortColumn) => {
        setParamSort((prev) =>
            prev?.column === column
                ? { column, direction: prev.direction === "ascending" ? "descending" : "ascending" }
                : { column, direction: "ascending" },
        );
    };

    if (!selectedPcf || selectedPcf.parameters.length === 0) {
        return null;
    }

    return (
        <Table size="small">
            <TableHeader>
                <TableRow>
                    <TableHeaderCell
                        className={mergeClasses(styles.tableHeaderCell, styles.colName)}
                        sortable
                        sortDirection={paramSort?.column === "name" ? paramSort.direction : undefined}
                        onClick={() => toggleParamSort("name")}
                    >
                        <Tooltip
                            content="The parameter's name as defined in the PCF control's manifest."
                            relationship="description"
                            positioning="below"
                            withArrow
                        >
                            <span>Param Name</span>
                        </Tooltip>
                    </TableHeaderCell>
                    <TableHeaderCell
                        className={mergeClasses(styles.tableHeaderCell, styles.colUsage)}
                        sortable
                        sortDirection={paramSort?.column === "usage" ? paramSort.direction : undefined}
                        onClick={() => toggleParamSort("usage")}
                    >
                        <Tooltip
                            content="Whether the parameter is bound to the field itself, or a configurable input/output value."
                            relationship="description"
                            positioning="below"
                            withArrow
                        >
                            <span>Param Usage</span>
                        </Tooltip>
                    </TableHeaderCell>
                    <TableHeaderCell
                        className={mergeClasses(styles.tableHeaderCell, styles.colRequired)}
                        sortable
                        sortDirection={paramSort?.column === "required" ? paramSort.direction : undefined}
                        onClick={() => toggleParamSort("required")}
                    >
                        <Tooltip
                            content="Whether the PCF control requires a value for this parameter."
                            relationship="description"
                            positioning="below"
                            withArrow
                        >
                            <span>Required?</span>
                        </Tooltip>
                    </TableHeaderCell>
                    <TableHeaderCell
                        className={mergeClasses(styles.tableHeaderCell, styles.colType)}
                        sortable
                        sortDirection={paramSort?.column === "type" ? paramSort.direction : undefined}
                        onClick={() => toggleParamSort("type")}
                    >
                        <Tooltip
                            content="The type (or type group) of value this parameter accepts."
                            relationship="description"
                            positioning="below"
                            withArrow
                        >
                            <span>Param Type</span>
                        </Tooltip>
                    </TableHeaderCell>
                    <TableHeaderCell
                        className={mergeClasses(styles.tableHeaderCell, styles.colIsStatic)}
                        sortable
                        sortDirection={paramSort?.column === "isStatic" ? paramSort.direction : undefined}
                        onClick={() => toggleParamSort("isStatic")}
                    >
                        <Tooltip
                            content="This port only supports static parameter values; binding a parameter to another field is not supported."
                            relationship="description"
                            positioning="below"
                            withArrow
                        >
                            <span>Is Static?</span>
                        </Tooltip>
                    </TableHeaderCell>
                    <TableHeaderCell className={mergeClasses(styles.tableHeaderCell, styles.colValue)}>
                        <Tooltip
                            content="The value applied to this parameter when the control is assigned to the field."
                            relationship="description"
                            positioning="below"
                            withArrow
                        >
                            <span>Param Value</span>
                        </Tooltip>
                    </TableHeaderCell>
                </TableRow>
            </TableHeader>
            <TableBody>
                {sortParams(selectedPcf.parameters, paramSort?.column ?? null, paramSort?.direction ?? "ascending").map((param) => {
                    const paramType = param.ofTypeGroup ?? param.ofType ?? "—";
                    const isEnum = paramType.toLowerCase() === "enum";
                    const isStatic = isEnum || (staticOverrides[param.name] ?? false);
                    const isLookup = paramType.toLowerCase().includes("lookup");
                    const isOptionSet = paramType.toLowerCase() === "optionset";
                    const isSingleLineText = paramType.toLowerCase() === "singleline.text";

                    const bindFieldOptions = isOptionSet
                        ? choiceFieldOptions
                        : isLookup
                          ? lookupFieldOptions
                          : isSingleLineText
                            ? textFieldOptions
                            : MOCK_BIND_FIELD_OPTIONS;

                    return (
                        <TableRow key={param.name}>
                            <TableCell className={styles.colName}>
                                <Link as="span">
                                    {param.name}
                                    {param.required ? " *" : ""}
                                </Link>
                            </TableCell>
                            <TableCell className={styles.colUsage}>
                                <span className={styles.usageCell}>
                                    {PARAM_USAGE_ICONS[param.usage]}
                                    {param.usage}
                                </span>
                            </TableCell>
                            <TableCell className={styles.colRequired}>
                                <Checkbox checked={param.required} disabled />
                            </TableCell>
                            <TableCell className={styles.colType}>{paramType}</TableCell>
                            <TableCell className={styles.colIsStatic}>
                                <Checkbox
                                    checked={isStatic}
                                    disabled={isEnum}
                                    onChange={
                                        isEnum
                                            ? undefined
                                            : (_, data) =>
                                                  onStaticOverridesChange((prev) => ({ ...prev, [param.name]: !!data.checked }))
                                    }
                                    title={
                                        isEnum
                                            ? "Enum parameters must always be static."
                                            : "This port only supports static parameter values; binding to another field is not supported yet."
                                    }
                                />
                            </TableCell>
                            <TableCell className={styles.colValue}>
                                {isStatic ? (
                                    <Input
                                        className={styles.valueControl}
                                        value={paramValues[param.name] ?? ""}
                                        onChange={(_, data) => onParamValuesChange((prev) => ({ ...prev, [param.name]: data.value }))}
                                    />
                                ) : (
                                    <Dropdown
                                        className={styles.valueControl}
                                        value={paramValues[param.name] ?? ""}
                                        selectedOptions={paramValues[param.name] ? [paramValues[param.name]] : []}
                                        onOptionSelect={(_, data) =>
                                            onParamValuesChange((prev) => ({ ...prev, [param.name]: data.optionValue ?? "" }))
                                        }
                                    >
                                        {bindFieldOptions.map((option) => (
                                            <Option key={option} value={option}>
                                                {option}
                                            </Option>
                                        ))}
                                    </Dropdown>
                                )}
                            </TableCell>
                        </TableRow>
                    );
                })}
            </TableBody>
        </Table>
    );
}
