import type { CSSProperties } from "react";
import { Badge, mergeClasses, Text } from "@fluentui/react-components";
import { getAttributeTypeLabel } from "../../services";
import type { AttributeInfo, FieldInfo } from "../../services";
import { useFieldPropertiesCardStyles } from "../../styles";
import { GenericCard } from "./GenericCard";

interface IFieldPropertiesCardProps {
    field: FieldInfo;
    attribute: AttributeInfo | undefined;
    entityDisplayName: string;
    stageName: string;
    stageColor: string;
}

/** Read-only summary of the selected field's properties: type, entity, and required-on-stage state. */
export function FieldPropertiesCard({ field, attribute, entityDisplayName, stageName, stageColor }: IFieldPropertiesCardProps) {
    const styles = useFieldPropertiesCardStyles();
    const cssVars: CSSProperties = { ["--stage-color" as string]: stageColor };

    return (
        <GenericCard className={styles.spacing} title="Field properties" style={cssVars}>
            <span className={styles.stageBadge}>{stageName}</span>

            <Text className={styles.fieldName}>{field.label}</Text>
            <Text className={styles.fieldLogical}>{field.datafieldname}</Text>

            <div className={mergeClasses(styles.row, styles.firstRow)}>
                <span className={styles.rowLabel}>Type</span>
                <span className={styles.rowValue}>{attribute ? getAttributeTypeLabel(attribute.attributeType) : "Unknown"}</span>
            </div>

            <div className={styles.row}>
                <span className={styles.rowLabel}>Entity</span>
                <span className={styles.rowValue}>{entityDisplayName}</span>
            </div>

            <div className={styles.row}>
                <span className={styles.rowLabel}>Required on stage</span>
                <Badge appearance="tint" color={field.required ? "success" : "informative"}>
                    {field.required ? "Required" : "Optional"}
                </Badge>
            </div>
            <div className={styles.row}>
                <span className={styles.rowLabel}>Sequence</span>
                <span className={styles.rowValue}>{field.sequence}</span>
            </div>
        </GenericCard>
    );
}
