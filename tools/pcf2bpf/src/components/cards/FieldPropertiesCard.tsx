import type { CSSProperties } from "react";
import { Badge, mergeClasses, Text } from "@fluentui/react-components";
import { getAttributeTypeLabel } from "../../services";
import type { AttributeInfo, FieldInfo } from "../../services";
import { useFieldPropertiesCardStyles } from "../../styles";
import { GenericCard } from "./GenericCard";
import {
    ATTRIBUTE_TYPE_UNKNOWN_LABEL,
    BADGE_OPTIONAL_LABEL,
    BADGE_REQUIRED_LABEL,
    CARD_DESCRIPTION,
    CARD_TITLE,
    ROW_LABEL_ENTITY,
    ROW_LABEL_REQUIRED_ON_STAGE,
    ROW_LABEL_SEQUENCE,
    ROW_LABEL_TYPE,
} from "../../consts/FieldPropertiesCard.const";

export interface IFieldPropertiesCardProps {
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
        <GenericCard className={styles.spacing} title={CARD_TITLE} description={CARD_DESCRIPTION} style={cssVars}>
            <span className={styles.stageBadge}>{stageName}</span>

            <Text className={styles.fieldName}>{field.label}</Text>
            <Text className={styles.fieldLogical}>{field.datafieldname}</Text>

            <div className={mergeClasses(styles.row, styles.firstRow)}>
                <span className={styles.rowLabel}>{ROW_LABEL_TYPE}</span>
                <span className={styles.rowValue}>
                    {attribute ? getAttributeTypeLabel(attribute.attributeType) : ATTRIBUTE_TYPE_UNKNOWN_LABEL}
                </span>
            </div>

            <div className={styles.row}>
                <span className={styles.rowLabel}>{ROW_LABEL_ENTITY}</span>
                <span className={styles.rowValue}>{entityDisplayName}</span>
            </div>

            <div className={styles.row}>
                <span className={styles.rowLabel}>{ROW_LABEL_REQUIRED_ON_STAGE}</span>
                <Badge appearance="tint" color={field.required ? "success" : "informative"}>
                    {field.required ? BADGE_REQUIRED_LABEL : BADGE_OPTIONAL_LABEL}
                </Badge>
            </div>
            <div className={styles.row}>
                <span className={styles.rowLabel}>{ROW_LABEL_SEQUENCE}</span>
                <span className={styles.rowValue}>{field.sequence}</span>
            </div>
        </GenericCard>
    );
}
