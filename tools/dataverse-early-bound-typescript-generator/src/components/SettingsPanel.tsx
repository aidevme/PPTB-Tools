import { Button, DrawerBody, DrawerHeader, DrawerHeaderTitle, OverlayDrawer, Text } from '@fluentui/react-components';
import { DismissRegular } from '@fluentui/react-icons';

export interface SettingsPanelProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

/** Tool settings, shown in an overlay drawer that slides in from the right edge. */
export function SettingsPanel({ open, onOpenChange }: SettingsPanelProps) {
    return (
        <OverlayDrawer position="end" size="medium" open={open} onOpenChange={(_, data) => onOpenChange(data.open)}>
            <DrawerHeader>
                <DrawerHeaderTitle
                    action={<Button appearance="subtle" aria-label="Close" icon={<DismissRegular />} onClick={() => onOpenChange(false)} />}
                >
                    Settings
                </DrawerHeaderTitle>
            </DrawerHeader>
            <DrawerBody>
                <Text size={200}>No settings yet.</Text>
            </DrawerBody>
        </OverlayDrawer>
    );
}
