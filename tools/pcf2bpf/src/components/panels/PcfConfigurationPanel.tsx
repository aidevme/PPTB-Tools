import { Button, MessageBar, MessageBarBody } from "@fluentui/react-components";
import { useToolContext } from "../../services/pptbtoolservice";
import { getStageColor } from "../../services";
import type { AttributeInfo, BpfProcess, FieldInfo, FormFactor, PcfAssignment, PcfControl, StageInfo } from "../../services";
import { usePcfConfigurationPanelStyles } from "../../styles";
import { BpfSelectorCard } from "../cards/BpfSelectorCard";
import { CopyFormFactorCard } from "../cards/CopyFormFactorCard";
import { FieldPropertiesCard } from "../cards/FieldPropertiesCard";
import { FormFactorsCard } from "../cards/FormFactorsCard";
import { ScopeCard } from "../cards/ScopeCard";
import { StagesFieldsCard } from "../cards/StagesFieldsCard";

interface IPcfConfigurationPanelProps {
    onSelectBpf: (workflowId: string) => void;
    selectedBpf: BpfProcess | null;
    formError: string | null;

    doc: XMLDocument | null;
    docVersion: number;
    stages: StageInfo[];
    /** Entity display names keyed by logical name, covering every entity any field belongs to
     * (not just the BPF's `primaryentity`) — multi-entity BPFs have fields from different entities. */
    entityDisplayNamesByEntity: Record<string, string>;
    /** Display name of the entity the *selected* field belongs to. */
    selectedFieldEntityDisplayName: string;
    /** The BPF's own `primaryentity` logical name, used as the fallback entity for fields whose
     * `relationship` attribute doesn't resolve to one (see `getFieldEntityLogicalName`). */
    primaryEntityLogicalName: string;
    selectedField: FieldInfo | null;
    onSelectField: (field: FieldInfo) => void;

    isDirty: boolean;
    isPublishing: boolean;
    onUpdateAndPublish: () => void;

    attribute: AttributeInfo | undefined;
    selectedStageIndex: number;
    compatibleControls: PcfControl[];
    selectedFormFactor: FormFactor;
    onFormFactorChange: (formFactor: FormFactor) => void;
    existingAssignment: PcfAssignment | null;
    onApplyPcf: (pcf: PcfControl, values: Record<string, string>) => void;
    onRemovePcf: () => void;

    onCopyFormFactor: (from: FormFactor, to: FormFactor) => void;
}

/**
 * The "PCFs Configuration" tab's layout: solution/publisher and BPF pickers plus the stage/field list
 * and "Update and Publish" action in a fixed-width left column; to its right, a row with the selected
 * field's properties and the copy-between-form-factors action (only once a field is selected) side by
 * side, followed by the form-factor/PCF editor spanning their combined width so its parameter table
 * isn't squeezed into a narrower column. Solution/publisher/BPF picker state and PCF controls live in
 * `ToolContext` (read here only for the `bpfProcesses.length` gate — `ScopeCard` and `BpfSelectorCard`
 * read the rest themselves); the loaded-BPF-form state below is still `App.tsx`'s.
 */
export function PcfConfigurationPanel({
    onSelectBpf,
    selectedBpf,
    formError,
    doc,
    docVersion,
    stages,
    entityDisplayNamesByEntity,
    selectedFieldEntityDisplayName,
    primaryEntityLogicalName,
    selectedField,
    onSelectField,
    isDirty,
    isPublishing,
    onUpdateAndPublish,
    attribute,
    selectedStageIndex,
    compatibleControls,
    selectedFormFactor,
    onFormFactorChange,
    existingAssignment,
    onApplyPcf,
    onRemovePcf,
    onCopyFormFactor,
}: IPcfConfigurationPanelProps) {
    const styles = usePcfConfigurationPanelStyles();
    const { bpfProcesses } = useToolContext();

    return (
        <div className={styles.configRow}>
            <div className={styles.leftColumn}>
                <ScopeCard />

                {bpfProcesses.length > 0 && <BpfSelectorCard onSelect={onSelectBpf} />}

                {formError && (
                    <MessageBar intent="error">
                        <MessageBarBody>{formError}</MessageBarBody>
                    </MessageBar>
                )}

                <StagesFieldsCard
                    doc={doc}
                    docVersion={docVersion}
                    bpfName={selectedBpf?.name ?? ""}
                    stages={stages}
                    entityDisplayNamesByEntity={entityDisplayNamesByEntity}
                    primaryEntityLogicalName={primaryEntityLogicalName}
                    selectedControlId={selectedField?.controlId ?? null}
                    onSelectField={onSelectField}
                />

                <Button
                    className={styles.fullWidth}
                    appearance="primary"
                    size="large"
                    disabled={!isDirty || isPublishing}
                    onClick={onUpdateAndPublish}
                >
                    {isPublishing ? "Saving & Publishing..." : "Update and Publish"}
                </Button>
            </div>

            <div className={styles.rightArea}>
                <div className={styles.topRow}>
                    {selectedField && selectedStageIndex !== -1 && (
                        <div className={styles.fieldPropertiesColumn}>
                            <FieldPropertiesCard
                                field={selectedField}
                                attribute={attribute}
                                entityDisplayName={selectedFieldEntityDisplayName}
                                stageName={stages[selectedStageIndex].name}
                                stageColor={getStageColor(selectedStageIndex)}
                            />
                        </div>
                    )}
                    {selectedField && (
                        <div className={styles.copyColumn}>
                            <CopyFormFactorCard onCopy={onCopyFormFactor} />
                        </div>
                    )}
                </div>

                <FormFactorsCard
                    field={selectedField}
                    entityDisplayName={selectedFieldEntityDisplayName}
                    doc={doc}
                    docVersion={docVersion}
                    formFactor={selectedFormFactor}
                    onFormFactorChange={onFormFactorChange}
                    attribute={attribute}
                    compatibleControls={compatibleControls}
                    existing={existingAssignment}
                    onApply={onApplyPcf}
                    onRemove={onRemovePcf}
                />
            </div>
        </div>
    );
}
