import { DocumentDatabaseRegular } from '@fluentui/react-icons';
import { SCOPE_INSTALLATION } from '../SettingsPanel.const';
import { StoredSettingsViewer } from '../SettingsParts';
import type { SectionDefinition } from '../SettingsTab.shared';

/**
 * The Settings panel's Advanced tab: what PPTB has stored for the tool, read-only. Nothing to set.
 *
 * @returns The tab's sections, in order.
 */
export function advancedTabSections(): SectionDefinition[] {
    return [
        {
            id: 'storedSettings',
            tab: 'advanced',
            title: 'PPTB tool settings',
            icon: <DocumentDatabaseRegular />,
            badges: [SCOPE_INSTALLATION, { label: 'Read-only' }],
            // Nothing to set: the card shows what PPTB has stored for the tool.
            settings: [],
            extra: <StoredSettingsViewer />,
        },
    ];
}
