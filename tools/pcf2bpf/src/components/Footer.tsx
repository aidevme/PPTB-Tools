import { useState } from "react";
import { Button, Link, Text, tokens } from "@fluentui/react-components";
import { Bug20Regular, Document20Regular, Open20Regular, Settings20Regular } from "@fluentui/react-icons";
import pkg from "../../package.json";
import { useFooterStyles } from "../styles";
import { useToolContext } from "../services/pptbtoolcontextservice";
import { DebuggerPanel } from "./panels/debugger/DebuggerPanel";
import { ToolConfigurationPanel } from "./panels/ToolConfigurationPanel";

const AUTHOR_URL = "https://github.com/aidevme";
const DOCS_URL = "https://github.com/aidevme/PPTB-Tools/blob/main/docs/pcf2bpf/index.md";
const REPO_URL = "https://github.com/aidevme/PPTB-Tools/tree/main/tools/pcf2bpf";

// Uses window.open + preventDefault instead of a plain link click, since this Footer renders
// inside a PPTB tool panel where a normal navigation would leave the tool instead of opening a new tab.
function openExternal(url: string): void {
    window.open(url, "_blank", "noopener,noreferrer");
}

/**
 * Fixed bar pinned to the viewport bottom, showing the package name/version/author (from
 * `package.json`) and quick links to its author, docs, and GitHub source.
 */
export function Footer() {
    const styles = useFooterStyles();
    const { isDebuggerOpen, setIsDebuggerOpen } = useToolContext();
    const [isConfigOpen, setIsConfigOpen] = useState(false);

    return (
        <footer className={styles.root}>
            <Text className={styles.text}>
                {pkg.displayName} v{pkg.version}
            </Text>
            <Text className={styles.text}>&bull;</Text>
            <Text className={styles.text}>
                by{" "}
                <Link
                    href={AUTHOR_URL}
                    onClick={(event) => {
                        event.preventDefault();
                        openExternal(AUTHOR_URL);
                    }}
                    style={{ color: tokens.colorNeutralForeground3 }}
                >
                    {pkg.author}
                </Link>
            </Text>
            <Text className={styles.text}>&bull;</Text>
            <Link
                href={DOCS_URL}
                onClick={(event) => {
                    event.preventDefault();
                    openExternal(DOCS_URL);
                }}
                className={styles.iconLink}
            >
                <Document20Regular />
                <span>Documentation</span>
            </Link>
            <Text className={styles.text}>&bull;</Text>
            <Link
                href={REPO_URL}
                onClick={(event) => {
                    event.preventDefault();
                    openExternal(REPO_URL);
                }}
                className={styles.iconLink}
            >
                <Open20Regular />
                <span>GitHub</span>
            </Link>
            <Text className={styles.text}>&bull;</Text>
            <Button
                appearance="subtle"
                icon={<Bug20Regular />}
                className={styles.iconLink}
                onClick={() => setIsDebuggerOpen(true)}
            >
                Debugger
            </Button>
            <Button
                appearance="subtle"
                icon={<Settings20Regular />}
                className={styles.iconLink}
                onClick={() => setIsConfigOpen(true)}
            >
                Configuration
            </Button>
            <DebuggerPanel open={isDebuggerOpen} onOpenChange={setIsDebuggerOpen} />
            <ToolConfigurationPanel open={isConfigOpen} onOpenChange={setIsConfigOpen} />
        </footer>
    );
}
