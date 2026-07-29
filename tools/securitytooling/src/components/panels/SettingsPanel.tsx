import React from "react";
import { Button, Drawer, DrawerBody, DrawerHeader, DrawerHeaderTitle, Text } from "@fluentui/react-components";
import { Dismiss24Regular } from "@fluentui/react-icons";

export interface ISettingsPanelProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

/** Settings panel opened from `HeaderToolbar`'s "Settings" button. */
export const SettingsPanel: React.FC<ISettingsPanelProps> = ({ open, onOpenChange }) => {
    return (
        <Drawer type="overlay" position="end" size="small" open={open} onOpenChange={(_, data) => onOpenChange(data.open)}>
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
                    Settings
                </DrawerHeaderTitle>
            </DrawerHeader>

            <DrawerBody>
                <Text>No settings are available yet.</Text>
            </DrawerBody>
        </Drawer>
    );
};
