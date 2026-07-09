import type { CSSProperties, ReactNode } from "react";
import { Button, Caption1, mergeClasses, Text, Tooltip } from "@fluentui/react-components";
import { MoreVertical20Regular } from "@fluentui/react-icons";
import { useGenericCardStyles } from "../../styles";

interface IGenericCardProps {
    /** Eyebrow-style heading shown at the top of the card, e.g. "Business Process Flow" — a plain
     * string for most cards, or richer markup (e.g. a partly bold field name) where needed. Omitted
     * entirely (no reserved space) when not given. */
    title?: ReactNode;
    /** Called when the "More" button (top-right of the title row) is clicked. Not yet wired up by any
     * card — the button renders regardless, ready for a future menu/action. */
    onMoreClick?: () => void;
    /** Tooltip text for the "More" button, and its accessible name (there's no visible label since the
     * button is icon-only). Defaults to `"More"`. */
    tooltipText?: string;
    /** Supporting text shown under the title row. Omitted entirely (no reserved space) when not given. */
    description?: string;
    /** Extra classes merged onto the card frame, e.g. for spacing or a `minWidth` override. */
    className?: string;
    /** Inline styles applied to the card frame, e.g. to set a `--stage-color` CSS custom property
     * consumed by children. */
    style?: CSSProperties;
    children: ReactNode;
}

/**
 * Shared card frame (border/radius/padding/background) and eyebrow heading used as the base/parent
 * for every card in the config tab's columns — `BpfSelectorCard`, `CopyFormFactorCard`,
 * `SolutionsPublishersCard` — so they read as a consistent set without each re-declaring the same
 * frame and heading styles.
 */
export function GenericCard({
    title,
    onMoreClick,
    tooltipText = "More...",
    description,
    className,
    style,
    children,
}: IGenericCardProps) {
    const styles = useGenericCardStyles();

    return (
        <div className={mergeClasses(styles.root, className)} style={style}>
            {title && (
                <div className={styles.headerBlock}>
                    <div className={mergeClasses(styles.titleRow, description && styles.titleRowWithDescription)}>
                        <Text block className={styles.eyebrow}>
                            {title}
                        </Text>
                        <Tooltip content={tooltipText} relationship="label" withArrow>
                            <Button
                                className={styles.moreButton}
                                appearance="subtle"
                                size="small"
                                icon={<MoreVertical20Regular />}
                                onClick={onMoreClick}
                            />
                        </Tooltip>
                    </div>
                    {description && (
                        <Caption1 block className={styles.description}>
                            {description}
                        </Caption1>
                    )}
                </div>
            )}
            {children}
        </div>
    );
}
