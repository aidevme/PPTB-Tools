import { CodeTextRegular } from '@fluentui/react-icons';
import { version } from '../../../../package.json';
import { TemplatesViewer } from '../SettingsParts';
import type { SectionDefinition } from '../SettingsTab.shared';

/**
 * The Settings panel's Templates tab: the EJS templates Generate writes, read-only. Nothing to set.
 *
 * @returns The tab's sections, in order.
 */
export function templatesTabSections(): SectionDefinition[] {
    return [
        {
            id: 'templates',
            tab: 'templates',
            title: 'dataverse-early-bound-typescript-generator templates',
            icon: <CodeTextRegular />,
            // The tool's own version, as in the header.
            badges: [{ label: `Version ${version}` }, { label: 'Read-only' }],
            // Nothing to set: the card only shows the templates.
            settings: [],
            extra: <TemplatesViewer />,
        },
    ];
}
