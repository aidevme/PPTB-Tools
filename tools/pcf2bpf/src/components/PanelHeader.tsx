import type { ComponentType } from "react";
import { Caption1, mergeClasses, Text } from "@fluentui/react-components";
import {
    CheckmarkCircle20Filled,
    ErrorCircle20Filled,
    Info20Filled,
    Warning20Filled,
    type FluentIconsProps,
} from "@fluentui/react-icons";
import { usePanelHeaderStyles } from "../styles";

/** Semantic status conveyed by a {@link PanelHeader}'s icon. `"none"` shows no icon. */
export type PanelHeaderIconType = "success" | "info" | "warning" | "error" | "none";

const ICON_BY_TYPE: Record<Exclude<PanelHeaderIconType, "none">, ComponentType<FluentIconsProps>> = {
    success: CheckmarkCircle20Filled,
    info: Info20Filled,
    warning: Warning20Filled,
    error: ErrorCircle20Filled,
};

export interface IPanelHeaderProps {
    /** Main heading text. */
    title: string;
    /** Supporting text shown under the title. */
    description: string;
    /** Status icon shown before the title, colored to match. `"none"` hides the icon. */
    iconType: PanelHeaderIconType;
    className?: string;
}

/** A panel/section heading: a status icon and title on one line, with a description underneath. */
export function PanelHeader({ title, description, iconType, className }: IPanelHeaderProps) {
    const styles = usePanelHeaderStyles();
    const Icon = iconType === "none" ? null : ICON_BY_TYPE[iconType];
    const iconColorClass = iconType === "none" ? undefined : styles[iconType];

    return (
        <div className={mergeClasses(styles.root, className)}>
            <div className={styles.titleRow}>
                {Icon && <Icon className={mergeClasses(styles.icon, iconColorClass)} />}
                <Text weight="semibold" size={400} block className={styles.title}>
                    {title}
                </Text>
            </div>
            <Caption1 block className={styles.description}>
                {description}
            </Caption1>
        </div>
    );
}
