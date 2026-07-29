import React from "react";
import { Body1, Title1 } from "@fluentui/react-components";
import { useHeaderStyles } from "../styles";

export const Header: React.FC = () => {
    const styles = useHeaderStyles();

    return (
        <header className={styles.header}>
            <Title1>⚛️ Security Tools</Title1>
            <Body1>A unified console for assessing Shadow AI, red-team reconnaissance, agent governance, and risky application exposure across your Microsoft cloud estate.</Body1>
        </header>
    );
};
