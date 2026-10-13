import { makeStyles, tokens } from '@fluentui/react-components';

/** Styles for `SettingsPanel`: vertical tabs beside the content, and the Save/Cancel footer. */
export const useSettingsPanelStyles = makeStyles({
    body: { display: 'flex', gap: tokens.spacingHorizontalL, alignItems: 'flex-start' },
    tabs: { flexShrink: 0 },
    content: { flexGrow: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalS },
    hint: { color: tokens.colorNeutralForeground3, paddingLeft: tokens.spacingHorizontalXXL },
    intro: { color: tokens.colorNeutralForeground3 },
    footer: { justifyContent: 'flex-end' },
});
