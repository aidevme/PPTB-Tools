import { makeStyles, shorthands, tokens } from '@fluentui/react-components';

/**
 * Styles for `ProjectFormDialog`: the surface, the title with its icon and subtitle, the form, the input icons, the
 * Location input beside its Browse button, and the details strip shown when editing.
 */
export const useProjectFormDialogStyles = makeStyles({
    surface: { maxWidth: '560px', borderRadius: tokens.borderRadiusXLarge, boxShadow: tokens.shadow28 },
    titleRow: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalM },
    titleIcon: {
        display: 'inline-flex',
        padding: tokens.spacingHorizontalS,
        borderRadius: tokens.borderRadiusLarge,
        backgroundColor: tokens.colorBrandBackground2,
        color: tokens.colorBrandForeground1,
        fontSize: '24px',
    },
    titleText: { display: 'flex', flexDirection: 'column' },
    subtitle: { color: tokens.colorNeutralForeground3, fontWeight: tokens.fontWeightRegular },
    form: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalL, paddingTop: tokens.spacingVerticalS },
    inputIcon: { color: tokens.colorNeutralForeground3 },
    location: { display: 'flex', gap: tokens.spacingHorizontalS },
    locationInput: { flexGrow: 1, minWidth: 0 },
    locationText: { fontFamily: tokens.fontFamilyMonospace, fontSize: tokens.fontSizeBase200 },
    details: {
        display: 'flex',
        alignItems: 'center',
        gap: tokens.spacingHorizontalS,
        padding: `${tokens.spacingVerticalS} ${tokens.spacingHorizontalM}`,
        borderRadius: tokens.borderRadiusLarge,
        backgroundColor: tokens.colorNeutralBackground2,
        color: tokens.colorNeutralForeground3,
        ...shorthands.border('1px', 'solid', tokens.colorNeutralStroke2),
    },
    detailsIcon: { fontSize: '16px', flexShrink: 0 },
    detailsValue: { color: tokens.colorNeutralForeground1, fontWeight: tokens.fontWeightSemibold },
});
