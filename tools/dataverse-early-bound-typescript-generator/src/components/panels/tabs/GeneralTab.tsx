import { Caption1, SpinButton } from '@fluentui/react-components';
import { AlertRegular, ListRegular } from '@fluentui/react-icons';
import { RECENT_PROJECT_COUNT_RANGE, SELECTION_ROW_LIMIT_RANGE } from '../../../config';
import { SCOPE_INSTALLATION } from '../SettingsPanel.const';
import { spinValue, switchControl, type SectionDefinition, type SettingsTabContext } from '../SettingsTab.shared';

/**
 * The Settings panel's General tab: notifications, and the Recent projects and Select table row limits.
 *
 * @param context - The draft, the saved settings, the draft's updaters and the panel's styles.
 * @returns The tab's sections, in order.
 */
export function generalTabSections(context: SettingsTabContext): SectionDefinition[] {
    const { draft, settings, updateGeneral, styles } = context;
    const general = draft.general;
    const savedGeneral = settings.general;
    const notificationSwitch = (key: 'showProjectLoadedNotification' | 'showPreviewReadyNotification' | 'showGenerationCompleteNotification') =>
        switchControl(general[key], (checked) => updateGeneral({ [key]: checked }));
    return [
        {
            id: 'notifications',
            tab: 'general',
            title: 'Notifications',
            icon: <AlertRegular />,
            badges: [SCOPE_INSTALLATION],
            settings: [
                {
                    id: 'projectLoaded',
                    title: 'Project loaded',
                    description: 'When a project opens.',
                    info: (
                        <>
                            Says whether the project's .dataverse-gen.json was found. Saved as{' '}
                            <code>general.showProjectLoadedNotification</code>.
                        </>
                    ),
                    keywords: 'notification toast open',
                    changed: general.showProjectLoadedNotification !== savedGeneral.showProjectLoadedNotification,
                    control: notificationSwitch('showProjectLoadedNotification'),
                },
                {
                    id: 'previewReady',
                    title: 'Preview ready',
                    description: 'When a preview finishes.',
                    info: (
                        <>
                            Summarizes what Generate would do. Saved as <code>general.showPreviewReadyNotification</code>.
                        </>
                    ),
                    keywords: 'notification toast',
                    changed: general.showPreviewReadyNotification !== savedGeneral.showPreviewReadyNotification,
                    control: notificationSwitch('showPreviewReadyNotification'),
                },
                {
                    id: 'generationComplete',
                    title: 'Generation complete',
                    description: 'When Generate finishes.',
                    info: (
                        <>
                            Lists the files written. The result also shows on the Preview card either way, and error notifications are
                            always shown. Saved as <code>general.showGenerationCompleteNotification</code>.
                        </>
                    ),
                    keywords: 'notification toast generate',
                    changed: general.showGenerationCompleteNotification !== savedGeneral.showGenerationCompleteNotification,
                    control: notificationSwitch('showGenerationCompleteNotification'),
                },
            ],
        },
        {
            id: 'lists',
            tab: 'general',
            title: 'Lists & startup',
            icon: <ListRegular />,
            badges: [SCOPE_INSTALLATION],
            settings: [
                {
                    id: 'recentProjects',
                    title: 'Recent projects',
                    description: 'Offered on the Project card; 0 hides the list.',
                    info: (
                        <>
                            From {RECENT_PROJECT_COUNT_RANGE.min} to {RECENT_PROJECT_COUNT_RANGE.max}. Saved as{' '}
                            <code>general.recentProjectCount</code>.
                        </>
                    ),
                    keywords: 'recent projects shown',
                    changed: general.recentProjectCount !== savedGeneral.recentProjectCount,
                    control: ({ labelledBy, describedBy }) => (
                        <>
                            <SpinButton
                                className={styles.number}
                                min={RECENT_PROJECT_COUNT_RANGE.min}
                                max={RECENT_PROJECT_COUNT_RANGE.max}
                                value={general.recentProjectCount}
                                aria-labelledby={labelledBy}
                                aria-describedby={describedBy}
                                onChange={(_, data) => updateGeneral({ recentProjectCount: spinValue(data, general.recentProjectCount) })}
                            />
                            <Caption1 className={styles.unit}>{general.recentProjectCount === 1 ? 'project' : 'projects'}</Caption1>
                        </>
                    ),
                },
                {
                    id: 'rowLimit',
                    title: 'Rows in the Select tables',
                    description: 'The most each table lists; search to find others.',
                    info: (
                        <>
                            From {SELECTION_ROW_LIMIT_RANGE.min} to {SELECTION_ROW_LIMIT_RANGE.max}, for tables, actions and functions.
                            Higher values can make large environments slower. Saved as <code>general.selectionRowLimit</code>.
                        </>
                    ),
                    keywords: 'rows shown limit select tables',
                    changed: general.selectionRowLimit !== savedGeneral.selectionRowLimit,
                    control: ({ labelledBy, describedBy }) => (
                        <>
                            <SpinButton
                                className={styles.number}
                                min={SELECTION_ROW_LIMIT_RANGE.min}
                                max={SELECTION_ROW_LIMIT_RANGE.max}
                                step={100}
                                value={general.selectionRowLimit}
                                aria-labelledby={labelledBy}
                                aria-describedby={describedBy}
                                onChange={(_, data) => updateGeneral({ selectionRowLimit: spinValue(data, general.selectionRowLimit) })}
                            />
                            <Caption1 className={styles.unit}>rows</Caption1>
                        </>
                    ),
                },
            ],
        },
    ];
}
