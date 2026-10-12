import React from "react";
import { Caption1 } from "@fluentui/react-components";
import packageJson from "../../package.json";
import { useFooterStyles } from "../styles";

export const Footer: React.FC = () => {
    const styles = useFooterStyles();

    return (
        <footer className={styles.footer}>
            <Caption1>
                {packageJson.displayName} v{packageJson.version}
            </Caption1>
        </footer>
    );
};
