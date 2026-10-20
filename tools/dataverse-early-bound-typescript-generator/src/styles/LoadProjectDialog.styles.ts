import { makeStyles, shorthands, tokens } from '@fluentui/react-components';

/**
 * Styles for `LoadProjectDialog`: the wide surface, the title with its icon and count, the toolbar with the
 * selection, the framed table with a tinted header, and the empty state.
 */
export const useLoadProjectDialogStyles = makeStyles({
    surface: { maxWidth: '1000px', width: '90vw', borderRadius: tokens.borderRadiusXLarge, boxShadow: tokens.shadow28 },
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
    content: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalS },
    toolbar: {
        paddingLeft: tokens.spacingHorizontalXS,
        paddingRight: tokens.spacingHorizontalS,
        borderRadius: tokens.borderRadiusLarge,
        backgroundColor: tokens.colorNeutralBackground2,
    },
    selection: { marginLeft: 'auto', color: tokens.colorNeutralForeground3, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' },
    selectionName: { color: tokens.colorNeutralForeground1, fontWeight: tokens.fontWeightSemibold },
    tableWrapper: {
        maxHeight: '360px',
        overflow: 'auto',
        ...shorthands.border('1px', 'solid', tokens.colorNeutralStroke2),
        borderRadius: tokens.borderRadiusLarge,
        boxShadow: tokens.shadow2,
        // The sticky header row gets a tint, so it stands apart from the rows scrolling under it.
        '& thead tr': { backgroundColor: tokens.colorNeutralBackground3 },
    },
    empty: {
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: tokens.spacingVerticalXS,
        padding: `${tokens.spacingVerticalXXL} ${tokens.spacingHorizontalL}`,
        textAlign: 'center',
        ...shorthands.border('1px', 'dashed', tokens.colorNeutralStroke1),
        borderRadius: tokens.borderRadiusLarge,
    },
    emptyIcon: { fontSize: '40px', color: tokens.colorBrandForeground1 },
    muted: { color: tokens.colorNeutralForeground3 },
});
