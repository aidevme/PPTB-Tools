import { Input } from '@fluentui/react-components';
import { DocumentCheckmarkRegular, FolderRegular } from '@fluentui/react-icons';
import { OutputPreview } from '../SettingsParts';
import { SCOPE_CONFIG_FILE, SCOPE_PROJECTS } from '../SettingsPanel.const';
import { switchControl, type SectionDefinition, type SettingDefinition, type SettingsTabContext } from '../SettingsTab.shared';

/**
 * The Settings panel's Options tab: the output folder and generated-file defaults every project starts from.
 *
 * @param context - The draft, the saved settings, the draft's updaters and the panel's styles.
 * @returns The tab's sections, in order.
 */
export function optionsTabSections(context: SettingsTabContext): SectionDefinition[] {
    const { draft, settings, updateProjectDefaults, styles } = context;
    return [
        {
            id: 'output',
            tab: 'options',
            title: 'Output',
            icon: <FolderRegular />,
            badges: [SCOPE_PROJECTS, SCOPE_CONFIG_FILE],
            settings: [
                {
                    id: 'outputRoot',
                    title: 'Output folder',
                    description: 'Where generated files go, relative to the project folder.',
                    info: (
                        <>
                            Sets the project's <code>output.outputRoot</code>. A blank value keeps the previous default.
                        </>
                    ),
                    keywords: 'output root path directory',
                    changed: draft.projectDefaults.outputRoot !== settings.projectDefaults.outputRoot,
                    layout: 'stacked',
                    control: ({ labelledBy, describedBy }) => (
                        <Input
                            className={styles.search}
                            value={draft.projectDefaults.outputRoot}
                            aria-labelledby={labelledBy}
                            aria-describedby={describedBy}
                            onChange={(_, data) => updateProjectDefaults({ outputRoot: data.value })}
                        />
                    ),
                },
            ],
        },
        {
            id: 'generatedFiles',
            tab: 'options',
            title: 'Generated files',
            icon: <DocumentCheckmarkRegular />,
            badges: [SCOPE_PROJECTS, SCOPE_CONFIG_FILE],
            extra: <OutputPreview defaults={draft.projectDefaults} />,
            settings: (
                [
                    ['generateEntityTypes', 'Early-bound entity interfaces', 'A typed interface per table, for dataverse-ify.', 'dataverse-ify entity types'],
                    ['generateFormContext', 'Form context helpers', 'A typed FormContext per table, for form scripts.', 'xrm formcontext form scripts'],
                    ['generateIndex', 'index.ts barrel file', 'An index.ts that re-exports every generated file.', 'barrel index exports'],
                ] as const
            ).map(
                ([key, title, description, keywords]): SettingDefinition => ({
                    id: key,
                    title,
                    description,
                    info: (
                        <>
                            Sets the project's <code>{key}</code>.
                        </>
                    ),
                    keywords,
                    changed: draft.projectDefaults[key] !== settings.projectDefaults[key],
                    control: switchControl(draft.projectDefaults[key], (checked) => updateProjectDefaults({ [key]: checked })),
                }),
            ),
        },
    ];
}
