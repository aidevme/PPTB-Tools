import { makeStyles, tokens } from '@fluentui/react-components';

/** Styles for `FileViewer` and `DiffViewer`: the header bar, tabs, the diff lines, and the empty state. */
export const useFileViewerStyles = makeStyles({
    root: { display: 'flex', flexDirection: 'column', minHeight: 0, height: '100%' },
    header: {
        display: 'flex',
        alignItems: 'center',
        gap: tokens.spacingHorizontalS,
        flexWrap: 'wrap',
        padding: `${tokens.spacingVerticalS} ${tokens.spacingHorizontalM}`,
        backgroundColor: tokens.colorNeutralBackground1,
        borderBottom: `1px solid ${tokens.colorNeutralStroke2}`,
    },
    headerText: { display: 'flex', flexDirection: 'column', minWidth: 0, flex: '1 1 200px' },
    nameRow: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS, flexWrap: 'wrap' },
    name: { fontFamily: tokens.fontFamilyMonospace, fontWeight: tokens.fontWeightSemibold },
    path: {
        fontFamily: tokens.fontFamilyMonospace,
        fontSize: tokens.fontSizeBase100,
        color: tokens.colorNeutralForeground3,
        overflow: 'hidden',
        textOverflow: 'ellipsis',
        whiteSpace: 'nowrap',
    },
    meta: { color: tokens.colorNeutralForeground3, fontSize: tokens.fontSizeBase200, whiteSpace: 'nowrap' },
    tabs: { padding: `0 ${tokens.spacingHorizontalS}`, backgroundColor: tokens.colorNeutralBackground1, borderBottom: `1px solid ${tokens.colorNeutralStroke2}` },
    content: { flexGrow: 1, overflow: 'auto', padding: tokens.spacingHorizontalS, backgroundColor: tokens.colorNeutralBackground3 },
    notice: { margin: tokens.spacingHorizontalS },

    // Empty state
    empty: {
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: tokens.spacingVerticalS,
        height: '100%',
        padding: tokens.spacingHorizontalXL,
        textAlign: 'center',
        color: tokens.colorNeutralForeground3,
    },
    emptyIcon: { fontSize: '48px', color: tokens.colorBrandForeground2 },
    kbd: {
        fontFamily: tokens.fontFamilyMonospace,
        fontSize: tokens.fontSizeBase100,
        padding: `0 ${tokens.spacingHorizontalXS}`,
        borderRadius: tokens.borderRadiusSmall,
        border: `1px solid ${tokens.colorNeutralStroke1}`,
        backgroundColor: tokens.colorNeutralBackground1,
    },

    // Diff
    // A grid rather than a CSS table, so the "unchanged lines" row can span every column.
    diff: {
        display: 'grid',
        gridTemplateColumns: 'max-content max-content max-content minmax(max-content, 1fr)',
        fontFamily: tokens.fontFamilyMonospace,
        fontSize: tokens.fontSizeBase200,
        lineHeight: tokens.lineHeightBase200,
    },
    // Rows only group their cells; backgrounds go on the cells.
    diffRow: { display: 'contents' },
    diffAdd: { backgroundColor: tokens.colorPaletteGreenBackground1 },
    diffRemove: { backgroundColor: tokens.colorPaletteRedBackground1 },
    // A new line with a note (a duplicated identifier); wins over the added/unchanged tint.
    diffFlagged: { backgroundColor: tokens.colorPaletteDarkOrangeBackground1 },
    diffFlaggedNumber: {
        color: tokens.colorPaletteDarkOrangeForeground1,
        fontWeight: tokens.fontWeightSemibold,
        boxShadow: `inset 3px 0 0 ${tokens.colorPaletteDarkOrangeBorder2}`,
    },
    gutter: {
        paddingRight: tokens.spacingHorizontalS,
        paddingLeft: tokens.spacingHorizontalXS,
        textAlign: 'right',
        color: tokens.colorNeutralForeground4,
        userSelect: 'none',
        whiteSpace: 'nowrap',
    },
    sign: { paddingRight: tokens.spacingHorizontalS, userSelect: 'none', color: tokens.colorNeutralForeground3 },
    signAdd: { color: tokens.colorPaletteGreenForeground1 },
    signRemove: { color: tokens.colorPaletteRedForeground1 },
    code: { whiteSpace: 'pre', paddingRight: tokens.spacingHorizontalS },
    skipped: {
        gridColumn: '1 / -1',
        margin: `${tokens.spacingVerticalXXS} 0`,
        padding: `${tokens.spacingVerticalXXS} ${tokens.spacingHorizontalS}`,
        color: tokens.colorNeutralForeground3,
        backgroundColor: tokens.colorNeutralBackground4,
        fontStyle: 'italic',
        userSelect: 'none',
    },
});
