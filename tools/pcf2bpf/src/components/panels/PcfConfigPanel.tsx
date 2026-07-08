import { useEffect, useMemo, useState } from "react";
import {
    Button,
    Divider,
    Dropdown,
    Field,
    Input,
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
import { usePcfConfigPanelStyles } from "../../styles";

/** Icon shown on each form factor's tab. */
const FORM_FACTOR_ICONS: Record<FormFactor, JSX.Element> = {
    0: <Desktop20Regular />,
    1: <Phone20Regular />,
    2: <Tablet20Regular />,
};

interface IPcfConfigPanelProps {
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

export function PcfConfigPanel({
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
}: IPcfConfigPanelProps) {
    const styles = usePcfConfigPanelStyles();
    const [selectedPcfId, setSelectedPcfId] = useState("");
    const [paramValues, setParamValues] = useState<Record<string, string>>({});

    const assignedByFormFactor = useMemo(() => {
        const map: Partial<Record<FormFactor, boolean>> = {};
        if (doc && field) {
            FORM_FACTORS.forEach((ff) => {
                map[ff] = !!getExistingCustomControl(doc, field.controlId, ff);
            });
        }
        return map;
        // docVersion drives recomputation after in-place XML mutations; doc itself never changes identity.
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [doc, docVersion, field?.controlId]);

    useEffect(() => {
        const match = compatibleControls.find((c) => c.name === existing?.name);
        setSelectedPcfId(match?.id ?? "");
        setParamValues(existing?.parameters ?? {});
        // Reset local editor state whenever the selected field, form factor, or its assignment changes.
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [field?.controlId, formFactor, existing?.name]);

    if (!field) {
        return null;
    }

    const selectedPcf = compatibleControls.find((c) => c.id === selectedPcfId);
    const configurableParams = selectedPcf?.parameters.filter((p) => p.usage !== "bound") ?? [];

    const handlePcfChange = (pcfId: string) => {
        setSelectedPcfId(pcfId);
        const pcf = compatibleControls.find((c) => c.id === pcfId);
        setParamValues(pcf?.name === existing?.name ? (existing?.parameters ?? {}) : {});
    };

    return (
        <div className={styles.root}>
            <Text className={styles.eyebrow}>
                Form Factors for{" "}
                <span style={{ fontWeight: 600 }}>
                    {field.label} ({entityDisplayName})
                </span>
            </Text>

            <TabList
                selectedValue={String(formFactor)}
                onTabSelect={(_: SelectTabEvent, data: SelectTabData) => onFormFactorChange(Number(data.value) as FormFactor)}
            >
                {FORM_FACTORS.map((ff) => (
                    <Tab key={ff} value={String(ff)} icon={FORM_FACTOR_ICONS[ff]}>
                        <span className={styles.tabLabel}>
                            {FORM_FACTOR_LABELS[ff]}
                            {assignedByFormFactor[ff] && (
                                <CheckmarkCircle16Filled className={styles.assignedIcon} aria-label="PCF assigned" />
                            )}
                        </span>
                    </Tab>
                ))}
            </TabList>

            {!attribute ? (
                <Text italic>Could not resolve metadata for &quot;{field.datafieldname}&quot;</Text>
            ) : compatibleControls.length === 0 ? (
                <Text italic>No registered PCF control is compatible with &quot;{attribute.attributeType}&quot; fields</Text>
            ) : (
                <>
                    <Field label="Select a compatible PCF">
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
                    {selectedPcf && <Divider>PCF Details</Divider>}
                </>
            )}

            {configurableParams.map((param) => (
                <Field key={param.name} label={param.name + (param.required ? " *" : "")}>
                    <Input
                        value={paramValues[param.name] ?? ""}
                        onChange={(_, data) => setParamValues((prev) => ({ ...prev, [param.name]: data.value }))}
                    />
                </Field>
            ))}

            <div style={{ display: "flex", gap: 8 }}>
                <Tooltip
                    content={
                        selectedPcf
                            ? `Assigns "${selectedPcf.name}" (with the parameter values above) to this field on the ${FORM_FACTOR_LABELS[formFactor]} form factor, overwriting whatever control is already configured there. Nothing is saved to Dataverse until you click Update and Publish.`
                            : "Select a compatible PCF control above to enable assigning it to this field."
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
                        Add Control / Apply Changes
                    </Button>
                </Tooltip>
                <Tooltip
                    content={
                        existing
                            ? `Removes "${existing.name}" from this field on the ${FORM_FACTOR_LABELS[formFactor]} form factor. Nothing is saved to Dataverse until you click Update and Publish.`
                            : "This field has no PCF control assigned on the current form factor, so there's nothing to remove."
                    }
                    relationship="description"
                    positioning="below"
                    withArrow
                >
                    <Button appearance="secondary" disabledFocusable={!existing} onClick={() => existing && onRemove()}>
                        Remove Control
                    </Button>
                </Tooltip>
            </div>
        </div>
    );
}
