import { createElement, type ReactElement } from 'react';
import { CodeRegular, CodeTextRegular, OptionsRegular, WrenchRegular } from '@fluentui/react-icons';
import type { SectionBadge } from './SettingsParts';

/** The ids a setting's control is labelled and described by: its row's title and description. */
export type ControlIds = { labelledBy: string; describedBy: string };

/** The Settings panel's tabs. */
export type SettingsTab = 'general' | 'options' | 'files' | 'templates';

// A .ts file, so the tab icons are created with createElement rather than JSX.
export const TABS: Array<{ value: SettingsTab; label: string; subtitle: string; icon: ReactElement }> = [
    { value: 'general', label: 'General', subtitle: 'Notifications and lists', icon: createElement(OptionsRegular) },
    { value: 'options', label: 'Options', subtitle: 'What every project generates', icon: createElement(WrenchRegular) },
    { value: 'files', label: 'Generate & files', subtitle: 'Confirmations and orphans', icon: createElement(CodeRegular) },
    { value: 'templates', label: 'Templates', subtitle: 'EJS templates', icon: createElement(CodeTextRegular) },
];

/** One-line explanation at the top of each tab. */
export const TAB_INTROS: Record<SettingsTab, string> = {
    general: 'How the tool itself behaves.',
    options: 'Applied whenever a project opens; you can still change them per project on the Options card.',
    files: 'How Generate treats files in the output folders, for every project.',
    templates: 'The EJS templates Generate writes to each project. For reference only; nothing to change here.',
};

export const SCOPE_INSTALLATION: SectionBadge = { label: 'This PPTB installation' };
export const SCOPE_PROJECTS: SectionBadge = { label: 'Default for every project', color: 'brand' };
export const SCOPE_CONFIG_FILE: SectionBadge = { label: '.dataverse-gen.json' };
export const SCOPE_ALL_PROJECTS: SectionBadge = { label: 'All projects' };
