import type { ReactElement, ReactNode } from 'react';
import { Switch } from '@fluentui/react-components';
import type { ToolConfig } from '../../config';
import type { useSettingsDraft } from '../../hooks';
import type { useSettingsPanelStyles } from '../../styles';
import type { SectionBadge } from './SettingsParts';
import type { ControlIds, SettingsTab } from './SettingsPanel.const';

/** A setting as listed in a section; also what search matches against. */
export interface SettingDefinition {
    id: string;
    title: string;
    description: string;
    info?: ReactNode;
    /** Extra words search should match, beyond the title and description. */
    keywords?: string;
    changed: boolean;
    layout?: 'inline' | 'stacked';
    control: (ids: ControlIds) => ReactNode;
    /** Shown under the row, e.g. a warning while the setting is on. */
    note?: ReactNode;
}

/** A card of settings on one tab of the Settings panel. */
export interface SectionDefinition {
    id: string;
    tab: SettingsTab;
    title: string;
    icon: ReactElement;
    badges: SectionBadge[];
    danger?: boolean;
    settings: SettingDefinition[];
    extra?: ReactNode;
}

/** What a tab's sections read and change: the draft, the saved settings, the draft's updaters and the panel's styles. */
export interface SettingsTabContext extends Pick<ReturnType<typeof useSettingsDraft>, 'draft' | 'update' | 'updateProjectDefaults' | 'updateGeneral'> {
    /** The saved settings, to mark the changed values. */
    settings: ToolConfig;
    /** The Settings panel's styles. */
    styles: ReturnType<typeof useSettingsPanelStyles>;
    /** Copies text to the clipboard; `label` names it in the confirmation. The Advanced tab's Copy button uses it. */
    onCopyText?: (text: string, label: string) => void;
}

/**
 * A setting row's Switch, labelled and described by the row's title and description.
 *
 * @param checked - Whether the switch is on.
 * @param onChange - Called with the new value.
 * @returns The row's `control`.
 */
export const switchControl =
    (checked: boolean, onChange: (checked: boolean) => void) =>
    ({ labelledBy, describedBy }: ControlIds) => (
        <Switch checked={checked} aria-labelledby={labelledBy} aria-describedby={describedBy} onChange={(_, data) => onChange(data.checked)} />
    );

/**
 * A SpinButton's new value: the stepped value, or the typed text when the user typed one. Out-of-range or
 * fractional values are clamped and rounded when the settings are saved (`mergeToolConfig`).
 *
 * @param data - The SpinButton's change data.
 * @param current - The value before the change, kept when the typed text isn't a number.
 * @returns The new value.
 */
export function spinValue(data: { value?: number | null; displayValue?: string }, current: number): number {
    if (typeof data.value === 'number') return data.value;
    const typed = Number(data.displayValue);
    return data.displayValue !== undefined && data.displayValue.trim() !== '' && Number.isFinite(typed) ? typed : current;
}
