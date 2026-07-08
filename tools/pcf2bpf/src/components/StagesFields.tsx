import { useMemo, useState, type CSSProperties } from "react";
import { Badge, mergeClasses, Text } from "@fluentui/react-components";
import { ChevronDown16Regular, ChevronRight12Regular, ChevronRight16Regular } from "@fluentui/react-icons";
import { getStageColor, hasAnyCustomControl, getFieldsForStage } from "../services";
import type { FieldInfo, StageInfo } from "../services";
import { useStagesFieldsStyles } from "../styles";

interface Props {
    doc: XMLDocument | null;
    docVersion: number;
    /** Name of the selected Business Process Flow, shown under the "Business Process Details" title. */
    bpfName: string;
    stages: StageInfo[];
    entityDisplayName: string;
    selectedControlId: string | null;
    onSelectField: (field: FieldInfo) => void;
}

export function StagesFields({ doc, docVersion, bpfName, stages, entityDisplayName, selectedControlId, onSelectField }: Props) {
    const styles = useStagesFieldsStyles();

    const stageFields = useMemo(() => {
        const map = new Map<string, FieldInfo[]>();
        if (!doc) return map;
        stages.forEach((stage) => map.set(stage.id, getFieldsForStage(doc, stage.id)));
        return map;
        // docVersion drives recomputation after in-place XML mutations; doc itself never changes identity.
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [doc, docVersion, stages]);

    // Only the first stage starts open, matching a typical accordion default; any number of stages
    // can be open at once (independent per-stage toggle, not mutually exclusive).
    const [openStageIds, setOpenStageIds] = useState<Set<string>>(() => new Set(stages[0] ? [stages[0].id] : []));

    if (!doc) return null;

    const toggleStage = (stageId: string) => {
        setOpenStageIds((prev) => {
            const next = new Set(prev);
            if (next.has(stageId)) next.delete(stageId);
            else next.add(stageId);
            return next;
        });
    };

    return (
        <div className={styles.root}>
            <Text className={styles.eyebrow}>Business Process Details</Text>
            <Text className={styles.bpfName}>{bpfName}</Text>
            <div className={styles.flow}>
                {stages.map((stage, index) => {
                    const color = getStageColor(index);
                    const cssVars: CSSProperties = { ["--stage-color" as string]: color };
                    const fields = stageFields.get(stage.id) ?? [];
                    const isOpen = openStageIds.has(stage.id);

                    return (
                        <div key={stage.id} className={styles.stage} style={cssVars}>
                            <div className={styles.stageNode} />
                            <div className={mergeClasses(styles.stageCard, isOpen && styles.stageCardOpen)}>
                                <button type="button" className={styles.stageHead} onClick={() => toggleStage(stage.id)}>
                                    <span className={styles.stageHeadLeft}>
                                        <span className={styles.stageTitle}>{stage.name}</span>
                                        <span className={styles.stageCount}>
                                            {fields.length} field{fields.length === 1 ? "" : "s"}
                                        </span>
                                    </span>
                                    {isOpen ? (
                                        <ChevronDown16Regular className={styles.stageChevron} />
                                    ) : (
                                        <ChevronRight16Regular className={styles.stageChevron} />
                                    )}
                                </button>

                                {isOpen && (
                                    <div className={styles.stageBody}>
                                        {fields.length === 0 ? (
                                            <Text italic className={styles.stageEmpty}>
                                                No fields on this stage
                                            </Text>
                                        ) : (
                                            <div className={styles.fieldList}>
                                                {fields.map((field) => {
                                                    const hasControl = doc ? hasAnyCustomControl(doc, field.controlId) : false;
                                                    const isSelected = field.controlId === selectedControlId;
                                                    return (
                                                        <button
                                                            key={field.controlId}
                                                            type="button"
                                                            className={mergeClasses(
                                                                styles.fieldChip,
                                                                isSelected && styles.fieldChipSelected,
                                                            )}
                                                            onClick={() => onSelectField(field)}
                                                        >
                                                            <span className={styles.fieldName}>{field.label}</span>
                                                            <Badge appearance="outline" size="small">
                                                                {entityDisplayName}
                                                            </Badge>
                                                            {hasControl && (
                                                                <Badge color="success" size="small">
                                                                    PCF
                                                                </Badge>
                                                            )}
                                                            <ChevronRight12Regular className={styles.fieldChevron} />
                                                        </button>
                                                    );
                                                })}
                                            </div>
                                        )}
                                    </div>
                                )}
                            </div>
                        </div>
                    );
                })}
            </div>
        </div>
    );
}
