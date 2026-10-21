import { DocumentDatabaseRegular } from '@fluentui/react-icons';
import { SCOPE_INSTALLATION } from '../SettingsPanel.const';
import { StoredSettingsViewer } from '../SettingsParts';
import type { SectionDefinition, SettingsTabContext } from '../SettingsTab.shared';

/**
 * The Settings panel's Advanced tab: what PPTB has stored for the tool, read-only, with Copy and Refresh. Nothing to set.
 *
 * @param context - The tabs' context; only its `onCopyText` is used, for the Copy button.
 * @returns The tab's sections, in order.
 */
export function advancedTabSections(context: SettingsTabContext): SectionDefinition[] {
    return [
        {
            id: 'storedSettings',
            tab: 'advanced',
            title: 'PPTB tool settings',
            icon: <DocumentDatabaseRegular />,
            badges: [SCOPE_INSTALLATION, { label: 'Read-only' }],
            // Nothing to set: the card shows what PPTB has stored for the tool.
            settings: [],
            extra: <StoredSettingsViewer onCopyText={context.onCopyText} />,
        },
    ];
}
