import { Text } from "@fluentui/react-components";
import { XmlFormatter } from "./XmlFormatter/XmlFormatter";
import { useFormXmlPanelStyles } from "../styles";

interface IFormXmlPanelProps {
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

    return (
        <div className={styles.root}>
            <div className={styles.column}>
                <Text weight="semibold" block className={styles.label}>
                    Before
                </Text>
                <XmlFormatter xml={beforeXml} placeholder="Load a Business Process Flow to see its form XML..." theme="light" prettyPrint />
            </div>

            <div className={styles.column}>
                <Text weight="semibold" block className={styles.label}>
                    After
                </Text>
                <XmlFormatter xml={afterXml} placeholder="Load a Business Process Flow to see its form XML..." theme="light" prettyPrint />
            </div>
        </div>
    );
}
