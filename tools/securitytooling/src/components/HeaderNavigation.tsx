import React from "react";
import { Breadcrumb, BreadcrumbButton, BreadcrumbDivider, BreadcrumbItem } from "@fluentui/react-components";
import { useHeaderNavigationStyles } from "../styles";

export interface IHeaderNavigationItem {
    /** Unique key for the item. */
    key: string;
    /** Label shown for this breadcrumb segment. */
    label: string;
    /** Called when this item is activated. Ignored for the last (current) item. */
    onClick?: () => void;
}

export interface IHeaderNavigationProps {
    /** Breadcrumb trail, from root to the current page. The last item is rendered as the
     * current, non-interactive segment. */
    items: IHeaderNavigationItem[];
}

/** Breadcrumb navigation for the Security Tools header, showing the path from the dashboard down
 * to the currently open module. */
export const HeaderNavigation: React.FC<IHeaderNavigationProps> = ({ items }) => {
    const styles = useHeaderNavigationStyles();

    return (
        <Breadcrumb aria-label="Security Tools navigation">
            {items.map((item, index) => {
                const isCurrent = index === items.length - 1;
                return (
                    <React.Fragment key={item.key}>
                        <BreadcrumbItem>
                            <BreadcrumbButton
                                current={isCurrent}
                                className={isCurrent ? styles.current : undefined}
                                onClick={isCurrent ? undefined : item.onClick}
                            >
                                {item.label}
                            </BreadcrumbButton>
                        </BreadcrumbItem>
                        {!isCurrent && <BreadcrumbDivider />}
                    </React.Fragment>
                );
            })}
        </Breadcrumb>
    );
};
