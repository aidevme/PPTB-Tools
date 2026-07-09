import { Button, MessageBar, MessageBarBody, Text } from "@fluentui/react-components";
import { getStageColor } from "../../services";
import type {
    AttributeInfo,
    BpfProcess,
    BpfScope,
    FieldInfo,
    FormFactor,
    PcfAssignment,
    PcfControl,
    StageInfo,
} from "../../services";
import { usePcfConfigurationPanelStyles } from "../../styles";
import { BpfSelectorCard, CopyFormFactorCard, FieldPropertiesCard, FormFactorsCard, SolutionsPublishersCard, StagesFieldsCard } from "../cards";

interface IPcfConfigurationPanelProps {
    bpfProcesses: BpfProcess[];
    isLoadingBpfs: boolean;
    onLoadBpfs: (scope: BpfScope) => void;
    onSolutionsPublishersLoadingChange: (isLoading: boolean) => void;

    selectedBpfId: string;
    onSelectBpf: (workflowId: string) => void;
    selectedBpf: BpfProcess | null;
    formError: string | null;
    isLoadingForm: boolean;

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
 * The "PCFs Configuration" tab's three-column layout: solution/publisher and BPF pickers plus the
 * stage/field list and "Update and Publish" action on the left, the selected field's properties and
 * form-factor/PCF editor in the middle, and the copy-between-form-factors action on the right (only
 * once a field is selected). All state and Dataverse calls live in `App.tsx`; this component is purely
 * presentational.
 */
export function PcfConfigurationPanel({
    bpfProcesses,
    isLoadingBpfs,
    onLoadBpfs,
    onSolutionsPublishersLoadingChange,
    selectedBpfId,
    onSelectBpf,
    selectedBpf,
    formError,
    isLoadingForm,
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

    return (
        <div className={styles.configRow}>
            <div className={styles.leftColumn}>
                <SolutionsPublishersCard
                    onLoadingChange={onSolutionsPublishersLoadingChange}
                    bpfProcesses={bpfProcesses}
                    isLoadingBpfs={isLoadingBpfs}
                    onLoadBpfs={onLoadBpfs}
                />

                {bpfProcesses.length > 0 && (
                    <BpfSelectorCard bpfProcesses={bpfProcesses} selectedBpfId={selectedBpfId} onSelect={onSelectBpf} />
                )}

                {formError && (
                    <MessageBar intent="error">
                        <MessageBarBody>{formError}</MessageBarBody>
                    </MessageBar>
                )}

                {isLoadingForm ? (
                    <Text italic>Loading Business Process Flow...</Text>
                ) : (
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
                )}

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

            <div className={styles.middleColumn}>
                {selectedField && selectedStageIndex !== -1 && (
                    <FieldPropertiesCard
                        field={selectedField}
                        attribute={attribute}
                        entityDisplayName={selectedFieldEntityDisplayName}
                        stageName={stages[selectedStageIndex].name}
                        stageColor={getStageColor(selectedStageIndex)}
                    />
                )}
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

            {selectedField && (
                <div className={styles.rightColumn}>
                    <CopyFormFactorCard onCopy={onCopyFormFactor} />
                </div>
            )}
        </div>
    );
}
