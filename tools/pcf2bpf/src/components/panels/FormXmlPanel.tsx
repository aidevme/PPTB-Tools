import { useState } from "react";
import {
    Button,
    Caption1,
    Menu,
    MenuButton,
    MenuItem,
    MenuList,
    MenuPopover,
    MenuTrigger,
    Text,
    Tooltip,
    useId,
} from "@fluentui/react-components";
import { FullScreenMinimize20Regular } from "@fluentui/react-icons";
import { XmlFormatter } from "../xmlformatter/XmlFormatter";
import { XmlSearchBox } from "../searchbox/XmlSearchBox";
import { CompareXmlsCheckBox } from "../checkbox/CompareXmlsCheckBox";
import { PanelHeader } from "../PanelHeader";
import { useFormXmlPanelStyles } from "../../styles";

export interface IFormXmlPanelProps {
    /** The form's original XML, as it was before any edits made this session. */
    beforeXml: string;
    /** The form's XML reflecting the current (possibly unsaved) edits. */
    afterXml: string;
}

/**
 * A panel displaying the XML of a Business Process Flow before and after changes.
 */
export function FormXmlPanel({ beforeXml, afterXml }: IFormXmlPanelProps) {
    const styles = useFormXmlPanelStyles();
    const [searchQuery, setSearchQuery] = useState("");
    const [showDifferences, setShowDifferences] = useState(false);
    // Which pane (if either) is shown maximized, hiding its sibling. `XmlFormatter` doesn't manage
    // its own container size, so this panel owns the decision and feeds it back as the `maximized` prop.
    const [maximizedPane, setMaximizedPane] = useState<"before" | "after" | null>(null);
    const beforeColumnId = useId("form-xml-before");
    const afterColumnId = useId("form-xml-after");

    return (
        <div className={styles.root}>
            <PanelHeader
                title="Xml Details"
                description="Compare the Business Process Flow form's XML before and after your changes."
                iconType="info"
            />

            <div className={styles.toolbar}>
                <XmlSearchBox value={searchQuery} onChange={setSearchQuery} />
                <CompareXmlsCheckBox checked={showDifferences} onChange={setShowDifferences} />
                <Tooltip
                    content={
                        maximizedPane === null
                            ? "Maximize the Before or After pane (via its own maximize button) to enable restoring them to their original side-by-side layout."
                            : "Restores the Before and After panes to their original side-by-side layout, undoing whichever one is currently maximized."
                    }
                    relationship="description"
                    positioning="below"
                    withArrow
                >
                    <Button
                        appearance="subtle"
                        size="small"
                        icon={<FullScreenMinimize20Regular />}
                        disabledFocusable={maximizedPane === null}
                        onClick={() => maximizedPane !== null && setMaximizedPane(null)}
                    >
                        Restore
                    </Button>
                </Tooltip>

                <Menu>
                    <MenuTrigger disableButtonEnhancement>
                        <MenuButton appearance="subtle" size="small">
                            Visualize
                        </MenuButton>
                    </MenuTrigger>

                    <MenuPopover>
                        <MenuList>
                            <MenuItem>Visualize Before XML</MenuItem>
                            <MenuItem>Visualize After XML</MenuItem>
                        </MenuList>
                    </MenuPopover>
                </Menu>
            </div>

            <div className={styles.columnsRow}>
                {maximizedPane !== "after" && (
                    <div id={beforeColumnId} className={styles.column}>
                        <Text weight="semibold" block className={styles.label}>
                            Before
                        </Text>
                        <Caption1 block className={styles.description}>
                            Original form XML, as loaded before any edits this session.
                        </Caption1>
                        <XmlFormatter
                            xml={beforeXml}
                            placeholder="Load a Business Process Flow to see its form XML..."
                            theme="light"
                            prettyPrint
                            highlightQuery={searchQuery}
                            compareXml={showDifferences ? afterXml : undefined}
                            diffHighlight="removed"
                            maximized={maximizedPane === "before"}
                            onMaximizedChange={(maximized) => setMaximizedPane(maximized ? "before" : null)}
                        />
                    </div>
                )}

                {maximizedPane !== "before" && (
                    <div id={afterColumnId} className={styles.column}>
                        <Text weight="semibold" block className={styles.label}>
                            After
                        </Text>
                        <Caption1 block className={styles.description}>
                            Current form XML, including your unsaved edits.
                        </Caption1>
                        <XmlFormatter
                            xml={afterXml}
                            placeholder="Load a Business Process Flow to see its form XML..."
                            theme="light"
                            prettyPrint
                            highlightQuery={searchQuery}
                            compareXml={showDifferences ? beforeXml : undefined}
                            diffHighlight="added"
                            maximized={maximizedPane === "after"}
                            onMaximizedChange={(maximized) => setMaximizedPane(maximized ? "after" : null)}
                        />
                    </div>
                )}
            </div>
        </div>
    );
}
