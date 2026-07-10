import { type Dispatch, type SetStateAction, useEffect, useMemo, useRef, useState } from "react";
import {
    Button,
    Divider,
    Dropdown,
    Field,
    MessageBar,
    MessageBarBody,
    MessageBarTitle,
    mergeClasses,
    Option,
    Tab,
    TabList,
    Text,
    Tooltip,
    type SelectTabData,
    type SelectTabEvent,
} from "@fluentui/react-components";
import { CheckmarkCircle16Filled, Desktop20Regular, Phone20Regular, Tablet20Regular } from "@fluentui/react-icons";
import { getExistingCustomControl, FORM_FACTORS, FORM_FACTOR_LABELS } from "../../services";
import type { AttributeInfo, FieldInfo, FormFactor, PcfAssignment, PcfControl } from "../../services";
import { useFormFactorsCardStyles } from "../../styles";
import { PcfConfiguratorTable } from "../tables/PcfConfiguratorTable";
import { GenericCard } from "./GenericCard";

/** Icon shown on each form factor's tab. */
const FORM_FACTOR_ICONS: Record<FormFactor, JSX.Element> = {
    0: <Desktop20Regular />,
    1: <Phone20Regular />,
    2: <Tablet20Regular />,
};

const CARD_TITLE_PREFIX = "Form Factors for";
const CARD_DESCRIPTION = "Assign, reconfigure, or remove a PCF control for the selected form factor.";

const TAB_ASSIGNED_ICON_ARIA_LABEL = "PCF assigned";

const TEXT_METADATA_UNRESOLVED_PREFIX = "Could not resolve metadata for";
const TEXT_NO_COMPATIBLE_CONTROL_PREFIX = "No registered PCF control is compatible with";
const TEXT_NO_COMPATIBLE_CONTROL_SUFFIX = "fields";

const FIELD_SELECT_PCF_LABEL = "Select a compatible PCF";

const TIPS_TITLE = "Tips :";
const TIPS_BODY_TEXT = 'If you are not binding your parameter to a field, please consider checking the "Is Static" box.';

const DIVIDER_PCF_DETAILS_LABEL = "PCF Details";
const ROW_LABEL_CONTROL_TYPE = "Control type";
const ROW_LABEL_MANIFEST_VERSION = "Manifest version";
const CONTROL_TYPE_VIRTUAL_LABEL = "Virtual";
const CONTROL_TYPE_STANDARD_LABEL = "Standard";
const MANIFEST_VERSION_UNKNOWN_LABEL = "Unknown";

const TOOLTIP_APPLY_ENABLED_PART1 = 'Assigns "';
const TOOLTIP_APPLY_ENABLED_PART2 = '" (with the parameter values above) to this field on the';
const TOOLTIP_APPLY_ENABLED_PART3 =
    "form factor, overwriting whatever control is already configured there. Nothing is saved to Dataverse until you click Update and Publish.";
const TOOLTIP_APPLY_DISABLED_TEXT = "Select a compatible PCF control above to enable assigning it to this field.";
const BUTTON_APPLY_LABEL = "Add Control / Apply Changes";

const TOOLTIP_REMOVE_ENABLED_PART1 = 'Removes "';
const TOOLTIP_REMOVE_ENABLED_PART2 = '" from this field on the';
const TOOLTIP_REMOVE_ENABLED_PART3 = "form factor. Nothing is saved to Dataverse until you click Update and Publish.";
const TOOLTIP_REMOVE_DISABLED_TEXT = "This field has no PCF control assigned on the current form factor, so there's nothing to remove.";
const BUTTON_REMOVE_LABEL = "Remove Control";

export interface IFormFactorsCardProps {
    field: FieldInfo | null;
    entityDisplayName: string;
    doc: XMLDocument | null;
    docVersion: number;
    formFactor: FormFactor;
    onFormFactorChange: (formFactor: FormFactor) => void;
    attribute: AttributeInfo | undefined;
    compatibleControls: PcfControl[];
    existing: PcfAssignment | null;
    onApply: (pcf: PcfControl, values: Record<string, string>) => void;
    onRemove: () => void;
}

/** Form-factor picker, PCF dropdown, and parameter editor for the currently selected field. */
export function FormFactorsCard({
    field,
    entityDisplayName,
    doc,
    docVersion,
    formFactor,
    onFormFactorChange,
    attribute,
    compatibleControls,
    existing,
    onApply,
    onRemove,
}: IFormFactorsCardProps) {
    const styles = useFormFactorsCardStyles();
    // Per-form-factor drafts, keyed by FormFactor, so switching tabs doesn't discard an unapplied pick
    // on another tab. Only re-seeded (per key) when that form factor's actual doc assignment changes.
    const [selectedPcfIdByFf, setSelectedPcfIdByFf] = useState<Partial<Record<FormFactor, string>>>({});
    const [paramValuesByFf, setParamValuesByFf] = useState<Partial<Record<FormFactor, Record<string, string>>>>({});
    // "Is Static?" per non-Enum parameter, owned here (rather than by PcfConfiguratorTable) so it can
    // be reset alongside `paramValues` on the same field/PCF changes below.
    const [staticOverridesByFf, setStaticOverridesByFf] = useState<Partial<Record<FormFactor, Record<string, boolean>>>>({});

    const existingByFormFactor = useMemo(() => {
        const map: Partial<Record<FormFactor, PcfAssignment | null>> = {};
        if (doc && field) {
            FORM_FACTORS.forEach((ff) => {
                map[ff] = getExistingCustomControl(doc, field.controlId, ff);
            });
        }
        return map;
        // docVersion drives recomputation after in-place XML mutations; doc itself never changes identity.
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [doc, docVersion, field?.controlId]);

    // Tracks what each form factor's slot was last seeded from, so the effect below can tell an actual
    // doc mutation (Apply/Remove/Copy) apart from merely switching tabs.
    const syncedRef = useRef<{ controlId: string | undefined; assignments: Partial<Record<FormFactor, PcfAssignment | null>> }>({
        controlId: undefined,
        assignments: {},
    });

    useEffect(() => {
        const fieldChanged = syncedRef.current.controlId !== field?.controlId;
        const changedFormFactors = fieldChanged
            ? FORM_FACTORS
            : FORM_FACTORS.filter((ff) => {
                  const prevAssignment = syncedRef.current.assignments[ff];
                  const assignment = existingByFormFactor[ff];
                  return (
                      (prevAssignment?.name ?? null) !== (assignment?.name ?? null) ||
                      JSON.stringify(prevAssignment?.parameters ?? {}) !== JSON.stringify(assignment?.parameters ?? {})
                  );
              });

        if (changedFormFactors.length > 0) {
            setSelectedPcfIdByFf((prev) => {
                const next = fieldChanged ? {} : { ...prev };
                changedFormFactors.forEach((ff) => {
                    const assignment = existingByFormFactor[ff];
                    const match = compatibleControls.find((c) => c.name === assignment?.name);
                    next[ff] = match?.id ?? "";
                });
                return next;
            });
            setParamValuesByFf((prev) => {
                const next = fieldChanged ? {} : { ...prev };
                changedFormFactors.forEach((ff) => {
                    next[ff] = existingByFormFactor[ff]?.parameters ?? {};
                });
                return next;
            });
            setStaticOverridesByFf((prev) => {
                const next = fieldChanged ? {} : { ...prev };
                changedFormFactors.forEach((ff) => {
                    next[ff] = {};
                });
                return next;
            });
        }

        syncedRef.current = { controlId: field?.controlId, assignments: existingByFormFactor };
    }, [field?.controlId, existingByFormFactor, compatibleControls]);

    if (!field) {
        return null;
    }

    const selectedPcfId = selectedPcfIdByFf[formFactor] ?? "";
    const paramValues = paramValuesByFf[formFactor] ?? {};
    const staticOverrides = staticOverridesByFf[formFactor] ?? {};
    const selectedPcf = compatibleControls.find((c) => c.id === selectedPcfId);

    const setParamValues: Dispatch<SetStateAction<Record<string, string>>> = (update) => {
        setParamValuesByFf((prev) => {
            const current = prev[formFactor] ?? {};
            const next = typeof update === "function" ? (update as (p: Record<string, string>) => Record<string, string>)(current) : update;
            return { ...prev, [formFactor]: next };
        });
    };

    const setStaticOverrides: Dispatch<SetStateAction<Record<string, boolean>>> = (update) => {
        setStaticOverridesByFf((prev) => {
            const current = prev[formFactor] ?? {};
            const next =
                typeof update === "function" ? (update as (p: Record<string, boolean>) => Record<string, boolean>)(current) : update;
            return { ...prev, [formFactor]: next };
        });
    };

    const handlePcfChange = (pcfId: string) => {
        setSelectedPcfIdByFf((prev) => ({ ...prev, [formFactor]: pcfId }));
        const pcf = compatibleControls.find((c) => c.id === pcfId);
        const assignment = existingByFormFactor[formFactor];
        setParamValuesByFf((prev) => ({
            ...prev,
            [formFactor]: pcf?.name === assignment?.name ? (assignment?.parameters ?? {}) : {},
        }));
        setStaticOverridesByFf((prev) => ({ ...prev, [formFactor]: {} }));
    };

    const WebPanel = (
        <>
            {!attribute ? (
                <Text italic>
                    {TEXT_METADATA_UNRESOLVED_PREFIX} &quot;{field.datafieldname}&quot;
                </Text>
            ) : compatibleControls.length === 0 ? (
                <Text italic>
                    {TEXT_NO_COMPATIBLE_CONTROL_PREFIX} &quot;{attribute.attributeType}&quot; {TEXT_NO_COMPATIBLE_CONTROL_SUFFIX}
                </Text>
            ) : (
                <>
                    <Field label={`${FIELD_SELECT_PCF_LABEL} - Web`}>
                        <Dropdown
                            value={selectedPcf?.name ?? ""}
                            selectedOptions={selectedPcfId ? [selectedPcfId] : []}
                            onOptionSelect={(_, data) => handlePcfChange(data.optionValue ?? "")}
                        >
                            {compatibleControls.map((pcf) => (
                                <Option key={pcf.id} value={pcf.id}>
                                    {pcf.name}
                                </Option>
                            ))}
                        </Dropdown>
                    </Field>

                    {selectedPcf && (
                        <MessageBar intent="warning">
                            <MessageBarBody>
                                <MessageBarTitle>{TIPS_TITLE}</MessageBarTitle> {TIPS_BODY_TEXT}
                            </MessageBarBody>
                        </MessageBar>
                    )}
                </>
            )}

            {selectedPcf && (
                <>
                    <Divider>{DIVIDER_PCF_DETAILS_LABEL}</Divider>
                    <div>
                        <div className={mergeClasses(styles.row, styles.firstRow)}>
                            <span className={styles.rowLabel}>{ROW_LABEL_CONTROL_TYPE}</span>
                            <span className={styles.rowValue}>
                                {selectedPcf.isVirtual ? CONTROL_TYPE_VIRTUAL_LABEL : CONTROL_TYPE_STANDARD_LABEL}
                            </span>
                        </div>
                        <div className={styles.row}>
                            <span className={styles.rowLabel}>{ROW_LABEL_MANIFEST_VERSION}</span>
                            <span className={styles.rowValue}>{selectedPcf.version || MANIFEST_VERSION_UNKNOWN_LABEL}</span>
                        </div>
                    </div>
                </>
            )}

            <PcfConfiguratorTable
                selectedPcf={selectedPcf}
                formFactorId={String(formFactor)}
                entityLogicalName={field.entityLogicalName}
                paramValues={paramValues}
                onParamValuesChange={setParamValues}
                staticOverrides={staticOverrides}
                onStaticOverridesChange={setStaticOverrides}
            />

            <div style={{ display: "flex", gap: 8 }}>
                <Tooltip
                    content={
                        selectedPcf
                            ? `${TOOLTIP_APPLY_ENABLED_PART1}${selectedPcf.name}${TOOLTIP_APPLY_ENABLED_PART2} ${FORM_FACTOR_LABELS[formFactor]} ${TOOLTIP_APPLY_ENABLED_PART3}`
                            : TOOLTIP_APPLY_DISABLED_TEXT
                    }
                    relationship="description"
                    positioning="below"
                    withArrow
                >
                    <Button
                        appearance="primary"
                        disabledFocusable={!selectedPcf}
                        onClick={() => selectedPcf && onApply(selectedPcf, paramValues)}
                    >
                        {BUTTON_APPLY_LABEL}
                    </Button>
                </Tooltip>
                <Tooltip
                    content={
                        existing
                            ? `${TOOLTIP_REMOVE_ENABLED_PART1}${existing.name}${TOOLTIP_REMOVE_ENABLED_PART2} ${FORM_FACTOR_LABELS[formFactor]} ${TOOLTIP_REMOVE_ENABLED_PART3}`
                            : TOOLTIP_REMOVE_DISABLED_TEXT
                    }
                    relationship="description"
                    positioning="below"
                    withArrow
                >
                    <Button appearance="secondary" disabledFocusable={!existing} onClick={() => existing && onRemove()}>
                        {BUTTON_REMOVE_LABEL}
                    </Button>
                </Tooltip>
            </div>
        </>
    );

    const PhonePanel = (
        <>
            {!attribute ? (
                <Text italic>
                    {TEXT_METADATA_UNRESOLVED_PREFIX} &quot;{field.datafieldname}&quot;
                </Text>
            ) : compatibleControls.length === 0 ? (
                <Text italic>
                    {TEXT_NO_COMPATIBLE_CONTROL_PREFIX} &quot;{attribute.attributeType}&quot; {TEXT_NO_COMPATIBLE_CONTROL_SUFFIX}
                </Text>
            ) : (
                <>
                    <Field label={`${FIELD_SELECT_PCF_LABEL} - Phone`}>
                        <Dropdown
                            value={selectedPcf?.name ?? ""}
                            selectedOptions={selectedPcfId ? [selectedPcfId] : []}
                            onOptionSelect={(_, data) => handlePcfChange(data.optionValue ?? "")}
                        >
                            {compatibleControls.map((pcf) => (
                                <Option key={pcf.id} value={pcf.id}>
                                    {pcf.name}
                                </Option>
                            ))}
                        </Dropdown>
                    </Field>

                    {selectedPcf && (
                        <MessageBar intent="warning">
                            <MessageBarBody>
                                <MessageBarTitle>{TIPS_TITLE}</MessageBarTitle> {TIPS_BODY_TEXT}
                            </MessageBarBody>
                        </MessageBar>
                    )}
                </>
            )}

            {selectedPcf && (
                <>
                    <Divider>{DIVIDER_PCF_DETAILS_LABEL}</Divider>
                    <div>
                        <div className={mergeClasses(styles.row, styles.firstRow)}>
                            <span className={styles.rowLabel}>{ROW_LABEL_CONTROL_TYPE}</span>
                            <span className={styles.rowValue}>
                                {selectedPcf.isVirtual ? CONTROL_TYPE_VIRTUAL_LABEL : CONTROL_TYPE_STANDARD_LABEL}
                            </span>
                        </div>
                        <div className={styles.row}>
                            <span className={styles.rowLabel}>{ROW_LABEL_MANIFEST_VERSION}</span>
                            <span className={styles.rowValue}>{selectedPcf.version || MANIFEST_VERSION_UNKNOWN_LABEL}</span>
                        </div>
                    </div>
                </>
            )}

            <PcfConfiguratorTable
                selectedPcf={selectedPcf}
                formFactorId={String(formFactor)}
                entityLogicalName={field.entityLogicalName}
                paramValues={paramValues}
                onParamValuesChange={setParamValues}
                staticOverrides={staticOverrides}
                onStaticOverridesChange={setStaticOverrides}
            />

            <div style={{ display: "flex", gap: 8 }}>
                <Tooltip
                    content={
                        selectedPcf
                            ? `${TOOLTIP_APPLY_ENABLED_PART1}${selectedPcf.name}${TOOLTIP_APPLY_ENABLED_PART2} ${FORM_FACTOR_LABELS[formFactor]} ${TOOLTIP_APPLY_ENABLED_PART3}`
                            : TOOLTIP_APPLY_DISABLED_TEXT
                    }
                    relationship="description"
                    positioning="below"
                    withArrow
                >
                    <Button
                        appearance="primary"
                        disabledFocusable={!selectedPcf}
                        onClick={() => selectedPcf && onApply(selectedPcf, paramValues)}
                    >
                        {BUTTON_APPLY_LABEL}
                    </Button>
                </Tooltip>
                <Tooltip
                    content={
                        existing
                            ? `${TOOLTIP_REMOVE_ENABLED_PART1}${existing.name}${TOOLTIP_REMOVE_ENABLED_PART2} ${FORM_FACTOR_LABELS[formFactor]} ${TOOLTIP_REMOVE_ENABLED_PART3}`
                            : TOOLTIP_REMOVE_DISABLED_TEXT
                    }
                    relationship="description"
                    positioning="below"
                    withArrow
                >
                    <Button appearance="secondary" disabledFocusable={!existing} onClick={() => existing && onRemove()}>
                        {BUTTON_REMOVE_LABEL}
                    </Button>
                </Tooltip>
            </div>
        </>
    );

    const TabletPanel = (
        <>
            {!attribute ? (
                <Text italic>
                    {TEXT_METADATA_UNRESOLVED_PREFIX} &quot;{field.datafieldname}&quot;
                </Text>
            ) : compatibleControls.length === 0 ? (
                <Text italic>
                    {TEXT_NO_COMPATIBLE_CONTROL_PREFIX} &quot;{attribute.attributeType}&quot; {TEXT_NO_COMPATIBLE_CONTROL_SUFFIX}
                </Text>
            ) : (
                <>
                   <Field label={`${FIELD_SELECT_PCF_LABEL} - Tablet`}>
                        <Dropdown
                            value={selectedPcf?.name ?? ""}
                            selectedOptions={selectedPcfId ? [selectedPcfId] : []}
                            onOptionSelect={(_, data) => handlePcfChange(data.optionValue ?? "")}
                        >
                            {compatibleControls.map((pcf) => (
                                <Option key={pcf.id} value={pcf.id}>
                                    {pcf.name}
                                </Option>
                            ))}
                        </Dropdown>
                    </Field>

                    {selectedPcf && (
                        <MessageBar intent="warning">
                            <MessageBarBody>
                                <MessageBarTitle>{TIPS_TITLE}</MessageBarTitle> {TIPS_BODY_TEXT}
                            </MessageBarBody>
                        </MessageBar>
                    )}
                </>
            )}

            {selectedPcf && (
                <>
                    <Divider>{DIVIDER_PCF_DETAILS_LABEL}</Divider>
                    <div>
                        <div className={mergeClasses(styles.row, styles.firstRow)}>
                            <span className={styles.rowLabel}>{ROW_LABEL_CONTROL_TYPE}</span>
                            <span className={styles.rowValue}>
                                {selectedPcf.isVirtual ? CONTROL_TYPE_VIRTUAL_LABEL : CONTROL_TYPE_STANDARD_LABEL}
                            </span>
                        </div>
                        <div className={styles.row}>
                            <span className={styles.rowLabel}>{ROW_LABEL_MANIFEST_VERSION}</span>
                            <span className={styles.rowValue}>{selectedPcf.version || MANIFEST_VERSION_UNKNOWN_LABEL}</span>
                        </div>
                    </div>
                </>
            )}

            <PcfConfiguratorTable
                selectedPcf={selectedPcf}
                formFactorId={String(formFactor)}
                entityLogicalName={field.entityLogicalName}
                paramValues={paramValues}
                onParamValuesChange={setParamValues}
                staticOverrides={staticOverrides}
                onStaticOverridesChange={setStaticOverrides}
            />

            <div style={{ display: "flex", gap: 8 }}>
                <Tooltip
                    content={
                        selectedPcf
                            ? `${TOOLTIP_APPLY_ENABLED_PART1}${selectedPcf.name}${TOOLTIP_APPLY_ENABLED_PART2} ${FORM_FACTOR_LABELS[formFactor]} ${TOOLTIP_APPLY_ENABLED_PART3}`
                            : TOOLTIP_APPLY_DISABLED_TEXT
                    }
                    relationship="description"
                    positioning="below"
                    withArrow
                >
                    <Button
                        appearance="primary"
                        disabledFocusable={!selectedPcf}
                        onClick={() => selectedPcf && onApply(selectedPcf, paramValues)}
                    >
                        {BUTTON_APPLY_LABEL}
                    </Button>
                </Tooltip>
                <Tooltip
                    content={
                        existing
                            ? `${TOOLTIP_REMOVE_ENABLED_PART1}${existing.name}${TOOLTIP_REMOVE_ENABLED_PART2} ${FORM_FACTOR_LABELS[formFactor]} ${TOOLTIP_REMOVE_ENABLED_PART3}`
                            : TOOLTIP_REMOVE_DISABLED_TEXT
                    }
                    relationship="description"
                    positioning="below"
                    withArrow
                >
                    <Button appearance="secondary" disabledFocusable={!existing} onClick={() => existing && onRemove()}>
                        {BUTTON_REMOVE_LABEL}
                    </Button>
                </Tooltip>
            </div>
        </>
    );

    return (
        <GenericCard
            title={
                <>
                    {CARD_TITLE_PREFIX}{" "}
                    <span style={{ fontWeight: 600 }}>
                        {field.label} ({entityDisplayName})
                    </span>
                </>
            }
            description={CARD_DESCRIPTION}
        >
            <div className={styles.content}>
                <TabList
                    selectedValue={String(formFactor)}
                    onTabSelect={(_: SelectTabEvent, data: SelectTabData) => onFormFactorChange(Number(data.value) as FormFactor)}
                >
                    {FORM_FACTORS.map((ff) => (
                        <Tab key={ff} value={String(ff)} icon={FORM_FACTOR_ICONS[ff]}>
                            <span className={styles.tabLabel}>
                                {FORM_FACTOR_LABELS[ff]}
                                {existingByFormFactor[ff] && (
                                    <CheckmarkCircle16Filled className={styles.assignedIcon} aria-label={TAB_ASSIGNED_ICON_ARIA_LABEL} />
                                )}
                            </span>
                        </Tab>
                    ))}
                </TabList>
                <div className={styles.content}>
                    {formFactor === 0 && WebPanel}
                    {formFactor === 1 && PhonePanel}
                    {formFactor === 2 && TabletPanel}
                </div>
            </div>
        </GenericCard>
    );
}
