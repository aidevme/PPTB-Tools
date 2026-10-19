import { createElement, type ReactElement } from 'react';
import { CodeRegular, CodeTextRegular, DeveloperBoardRegular, OptionsRegular, WrenchRegular } from '@fluentui/react-icons';
import type { SectionBadge } from './SettingsParts';

/** The ids a setting's control is labelled and described by: its row's title and description. */
export type ControlIds = {
    /** The id of the row's title, for the control's `aria-labelledby`. */
    labelledBy: string;
    /** The id of the row's description, for the control's `aria-describedby`. */
    describedBy: string;
};

/** The Settings panel's tabs. */
export type SettingsTab = 'general' | 'options' | 'files' | 'templates' | 'advanced';

/**
 * The navigation tabs, in order: each tab's label, the subtitle under it, and its icon.
 * @remarks This is a `.ts` file, so the icons are created with `createElement` rather than JSX.
 */
export const TABS: Array<{ value: SettingsTab; label: string; subtitle: string; icon: ReactElement }> = [
    { value: 'general', label: 'General', subtitle: 'Notifications and lists', icon: createElement(OptionsRegular) },
    { value: 'options', label: 'Options', subtitle: 'What every project generates', icon: createElement(WrenchRegular) },
    { value: 'files', label: 'Generate & files', subtitle: 'Confirmations and orphans', icon: createElement(CodeRegular) },
    { value: 'templates', label: 'Templates', subtitle: 'EJS templates', icon: createElement(CodeTextRegular) },
    { value: 'advanced', label: 'Advanced', subtitle: 'For power users', icon: createElement(DeveloperBoardRegular) },
];

/** One-line explanation at the top of each tab. */
export const TAB_INTROS: Record<SettingsTab, string> = {
    general: 'How the tool itself behaves.',
    options: 'Applied whenever a project opens; you can still change them per project on the Options card.',
    files: 'How Generate treats files in the output folders, for every project.',
    templates: 'The EJS templates Generate writes to each project. For reference only; nothing to change here.',
    advanced: 'Details most projects never need, such as what PPTB has stored for this tool.',
};

/** Badge for sections saved with the tool's settings in this PPTB installation (the General tab). */
export const SCOPE_INSTALLATION: SectionBadge = { label: 'This PPTB installation' };
/** Badge for defaults applied to every project when it opens (the Options tab). */
export const SCOPE_PROJECTS: SectionBadge = { label: 'Default for every project', color: 'brand' };
/** Badge for values that end up in each project's `.dataverse-gen.json`. */
export const SCOPE_CONFIG_FILE: SectionBadge = { label: '.dataverse-gen.json' };
/** Badge for tool settings that apply to every project (the Generate & files tab). */
export const SCOPE_ALL_PROJECTS: SectionBadge = { label: 'All projects' };
