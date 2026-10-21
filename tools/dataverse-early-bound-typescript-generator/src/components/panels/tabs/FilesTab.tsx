import { MessageBar, MessageBarBody } from '@fluentui/react-components';
import { CodeTextRegular, DeleteRegular, DocumentCheckmarkRegular, WarningRegular } from '@fluentui/react-icons';
import { TOOL_CONFIG_KEY } from '../../../core';
import { DEFAULT_TEMPLATE_ROOT } from '../../../services';
import {
    CUSTOM_ENUM_TEMPLATE_TITLE,
    DELETE_ORPHANS_INFO,
    DELETE_ORPHANS_TITLE,
    RENAME_DUPLICATES_INFO,
    RENAME_DUPLICATES_TITLE,
    SKIP_DUPLICATES_INFO,
    SKIP_DUPLICATES_TITLE,
} from '../../shared/settingsInfo';
import { SCOPE_ALL_PROJECTS } from '../SettingsPanel.const';
import { switchControl, type SectionDefinition, type SettingsTabContext } from '../SettingsTab.shared';

/**
 * The Settings panel's Generate & files tab: the confirmation before Generate, the templates, duplicate identifiers
 * (including the global Custom enum template default) and orphaned files.
 *
 * @param context - The draft, the saved settings, the draft's updaters and the panel's styles.
 * @returns The tab's sections, in order.
 */
export function filesTabSections(context: SettingsTabContext): SectionDefinition[] {
    const { draft, settings, update, updateProjectDefaults, styles } = context;
    return [
        {
            id: 'beforeGenerating',
            tab: 'files',
            title: 'Before generating',
            icon: <DocumentCheckmarkRegular />,
            badges: [SCOPE_ALL_PROJECTS],
            settings: [
                {
                    id: 'confirmBeforeGenerate',
                    title: 'Ask before generating',
                    description: 'Confirm before new and changed files are written.',
                    info: (
                        <>
                            The confirmation names the output folder and how many files will be created and overwritten. Overwrites
                            can't be undone, so use source control. When orphaned files are deleted too, their confirmation covers both.
                            Saved as <code>confirmBeforeGenerate</code>.
                        </>
                    ),
                    keywords: 'confirm confirmation overwrite',
                    changed: draft.confirmBeforeGenerate !== settings.confirmBeforeGenerate,
                    control: switchControl(draft.confirmBeforeGenerate, (checked) => update({ confirmBeforeGenerate: checked })),
                },
            ],
        },
        {
            id: 'templateFiles',
            tab: 'files',
            title: 'Templates',
            icon: <CodeTextRegular />,
            badges: [SCOPE_ALL_PROJECTS],
            settings: [
                {
                    id: 'generateTemplates',
                    title: 'Generate templates',
                    description: "Write dataverse-gen's EJS templates to the project's templateRoot.",
                    info: (
                        <>
                            Generate writes the templates to <code>templateRoot</code> (<code>{DEFAULT_TEMPLATE_ROOT}</code> by default),
                            overwriting edited copies, like <code>dataverse-gen eject</code>. When off, they aren't written and
                            existing copies are left as they are. The tool itself always uses its built-in templates. Saved as{' '}
                            <code>generateTemplates</code>.
                        </>
                    ),
                    keywords: 'templates ejs eject templateRoot dataverse-gen write',
                    changed: draft.generateTemplates !== settings.generateTemplates,
                    control: switchControl(draft.generateTemplates, (checked) => update({ generateTemplates: checked })),
                },
            ],
        },
        {
            id: 'duplicates',
            tab: 'files',
            title: 'Duplicate identifiers',
            icon: <WarningRegular />,
            badges: [SCOPE_ALL_PROJECTS],
            settings: [
                {
                    id: 'renameDuplicateIdentifiers',
                    title: RENAME_DUPLICATES_TITLE,
                    description: 'Give later duplicate enum members their value as a suffix, so the files compile.',
                    info: RENAME_DUPLICATES_INFO,
                    keywords: 'duplicate duplicated identifier identifiers enum label rename suffix compile',
                    changed: draft.renameDuplicateIdentifiers !== settings.renameDuplicateIdentifiers,
                    control: switchControl(draft.renameDuplicateIdentifiers, (checked) => update({ renameDuplicateIdentifiers: checked })),
                },
                {
                    id: 'customEnumTemplate',
                    title: CUSTOM_ENUM_TEMPLATE_TITLE,
                    description: "The default for projects that don't set their own; each project can change it on its Options card.",
                    info: (
                        <>
                            Renames duplicates and writes an <code>enum.ejs</code> that does the same for the dataverse-gen CLI. This is
                            the global default: it's used by every project whose <code>.dataverse-gen.json</code> doesn't set a value yet,
                            and it never replaces a project's own value. Each project turns it on or off on the Options card or in
                            Preview and generate, saved as <code>{TOOL_CONFIG_KEY}.customEnumTemplate</code>. The global value is saved
                            as <code>projectDefaults.customEnumTemplate</code>.
                        </>
                    ),
                    keywords: 'duplicate duplicated identifier identifiers enum label rename custom template ejs cli dataverse-gen global default project',
                    changed: draft.projectDefaults.customEnumTemplate !== settings.projectDefaults.customEnumTemplate,
                    control: switchControl(draft.projectDefaults.customEnumTemplate, (checked) => updateProjectDefaults({ customEnumTemplate: checked })),
                },
                {
                    id: 'skipDuplicateIdentifiers',
                    title: SKIP_DUPLICATES_TITLE,
                    description: "Don't write generated files that declare the same name more than once.",
                    info: SKIP_DUPLICATES_INFO,
                    keywords: 'duplicate duplicated identifier identifiers enum label skip compile',
                    changed: draft.skipDuplicateIdentifiers !== settings.skipDuplicateIdentifiers,
                    control: switchControl(draft.skipDuplicateIdentifiers, (checked) => update({ skipDuplicateIdentifiers: checked })),
                },
            ],
        },
        {
            id: 'orphans',
            tab: 'files',
            title: 'Orphaned files',
            icon: <DeleteRegular />,
            badges: [SCOPE_ALL_PROJECTS, { label: 'Permanent', color: 'danger' }],
            danger: true,
            settings: [
                {
                    id: 'deleteOrphanedFiles',
                    title: DELETE_ORPHANS_TITLE,
                    description: 'Delete generated files the selection no longer produces.',
                    info: DELETE_ORPHANS_INFO,
                    keywords: 'orphan orphaned delete remove cleanup',
                    changed: draft.deleteOrphanedFiles !== settings.deleteOrphanedFiles,
                    control: switchControl(draft.deleteOrphanedFiles, (checked) => update({ deleteOrphanedFiles: checked })),
                    note: draft.deleteOrphanedFiles ? (
                        <MessageBar intent="warning" className={styles.warning}>
                            <MessageBarBody>Files are deleted permanently, not moved to the Recycle Bin or Trash.</MessageBarBody>
                        </MessageBar>
                    ) : undefined,
                },
            ],
        },
    ];
}
