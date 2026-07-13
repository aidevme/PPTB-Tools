import {
    Button,
    DrawerBody,
    DrawerHeader,
    DrawerHeaderTitle,
    OverlayDrawer,
    Text,
} from "@fluentui/react-components";
import { Dismiss24Regular } from "@fluentui/react-icons";
import { useToolConfigurationPanelStyles } from "../../styles";

export interface IToolConfigurationPanelProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

/** Overlay drawer for tool-level configuration and settings. */
export function ToolConfigurationPanel({ open, onOpenChange }: IToolConfigurationPanelProps) {
    const styles = useToolConfigurationPanelStyles();

    return (
        <OverlayDrawer position="end" size="medium" open={open} onOpenChange={(_, data) => onOpenChange(data.open)}>
            <DrawerHeader>
                <DrawerHeaderTitle
                    action={
                        <Button
                            appearance="subtle"
                            aria-label="Close"
                            icon={<Dismiss24Regular />}
                            onClick={() => onOpenChange(false)}
                        />
                    }
                >
                    Tool Configuration
                </DrawerHeaderTitle>
            </DrawerHeader>
            <DrawerBody className={styles.body}>
                <Text italic>Nothing here yet.</Text>
            </DrawerBody>
        </OverlayDrawer>
    );
}
