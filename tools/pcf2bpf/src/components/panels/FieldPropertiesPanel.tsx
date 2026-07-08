import type { CSSProperties } from "react";
import { Badge, mergeClasses, Text } from "@fluentui/react-components";
import { getAttributeTypeLabel } from "../../lib";
import type { AttributeInfo, FieldInfo } from "../../lib";
import { useFieldPropertiesPanelStyles } from "../../styles";

interface IFieldPropertiesPanelProps {
    field: FieldInfo;
    attribute: AttributeInfo | undefined;
    entityDisplayName: string;
    stageName: string;
    stageColor: string;
}

/** Read-only summary of the selected field's properties: type, entity, and required-on-stage state. */
export function FieldPropertiesPanel({ field, attribute, entityDisplayName, stageName, stageColor }: IFieldPropertiesPanelProps) {
    const styles = useFieldPropertiesPanelStyles();
    const cssVars: CSSProperties = { ["--stage-color" as string]: stageColor };

    return (
        <div className={styles.root} style={cssVars}>
            <Text className={styles.eyebrow}>Field properties</Text>
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
        </div>
    );
}
