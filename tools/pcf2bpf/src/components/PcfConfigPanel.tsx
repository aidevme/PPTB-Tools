import { useEffect, useMemo, useState } from "react";
import { Button, Dropdown, Field, Input, Option, Text } from "@fluentui/react-components";
import { getExistingCustomControl, FORM_FACTORS, FORM_FACTOR_LABELS } from "../lib";
import type { AttributeInfo, FieldInfo, FormFactor, PcfAssignment, PcfControl } from "../lib";

interface Props {
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
}: Props) {
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
        return <Text italic>Select a field to configure its PCF control</Text>;
    }

    const selectedPcf = compatibleControls.find((c) => c.id === selectedPcfId);
    const configurableParams = selectedPcf?.parameters.filter((p) => p.usage !== "bound") ?? [];

    const handlePcfChange = (pcfId: string) => {
        setSelectedPcfId(pcfId);
        const pcf = compatibleControls.find((c) => c.id === pcfId);
        setParamValues(pcf?.name === existing?.name ? (existing?.parameters ?? {}) : {});
    };

    return (
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
            <Text>
                Form Factors for{" "}
                <span style={{ fontWeight: 600 }}>
                    {field.label} ({entityDisplayName})
                </span>
            </Text>

            <div style={{ display: "flex", gap: 24 }}>
                {FORM_FACTORS.map((ff) => {
                    const isActive = ff === formFactor;
                    return (
                        <button
                            key={ff}
                            onClick={() => onFormFactorChange(ff)}
                            style={{
                                display: "flex",
                                flexDirection: "column",
                                alignItems: "center",
                                gap: 4,
                                background: "none",
                                border: "none",
                                cursor: "pointer",
                                font: "inherit",
                            }}
                        >
                            <span style={{ fontWeight: isActive ? 700 : 600, textDecoration: isActive ? "underline" : "none" }}>
                                {FORM_FACTOR_LABELS[ff]}
                            </span>
                            <span
                                style={{
                                    display: "inline-flex",
                                    alignItems: "center",
                                    justifyContent: "center",
                                    width: 24,
                                    height: 24,
                                    borderRadius: "50%",
                                    backgroundColor: "#107C10",
                                    color: "white",
                                    fontWeight: 700,
                                }}
                            >
                                {assignedByFormFactor[ff] ? "✓" : "+"}
                            </span>
                        </button>
                    );
                })}
            </div>

            {!attribute ? (
                <Text italic>Could not resolve metadata for &quot;{field.datafieldname}&quot;</Text>
            ) : compatibleControls.length === 0 ? (
                <Text italic>No registered PCF control is compatible with &quot;{attribute.attributeType}&quot; fields</Text>
            ) : (
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
                <Button appearance="primary" disabled={!selectedPcf} onClick={() => selectedPcf && onApply(selectedPcf, paramValues)}>
                    Add Control / Apply Changes
                </Button>
                <Button appearance="secondary" disabled={!existing} onClick={onRemove}>
                    Remove Control
                </Button>
            </div>
        </div>
    );
}
