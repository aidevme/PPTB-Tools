import { makeStyles, tokens } from '@fluentui/react-components';

/** Styles for `WorkflowProgress`: the row of steps joined by connector lines across the top of the page. */
export const useWorkflowProgressStyles = makeStyles({
    list: {
        display: 'flex',
        alignItems: 'center',
        gap: tokens.spacingHorizontalS,
        margin: 0,
        padding: `${tokens.spacingVerticalS} ${tokens.spacingHorizontalM}`,
        listStyle: 'none',
        backgroundColor: tokens.colorNeutralBackground1,
        borderRadius: tokens.borderRadiusLarge,
        boxShadow: tokens.shadow4,
        overflowX: 'auto',
    },
    item: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS, flex: '1 1 0', minWidth: 0 },
    // The last step has no connector after it, so it doesn't grow.
    lastItem: { flex: '0 0 auto' },
    step: {
        display: 'flex',
        alignItems: 'center',
        gap: tokens.spacingHorizontalS,
        padding: `${tokens.spacingVerticalXS} ${tokens.spacingHorizontalS}`,
        border: 'none',
        borderRadius: tokens.borderRadiusMedium,
        backgroundColor: 'transparent',
        color: tokens.colorNeutralForeground1,
        cursor: 'pointer',
        textAlign: 'left',
        fontFamily: 'inherit',
        ':hover': { backgroundColor: tokens.colorNeutralBackground1Hover },
        ':focus-visible': { outline: `${tokens.strokeWidthThick} solid ${tokens.colorStrokeFocus2}` },
    },
    text: { display: 'flex', flexDirection: 'column', minWidth: 0 },
    title: { fontWeight: tokens.fontWeightSemibold, whiteSpace: 'nowrap' },
    status: { color: tokens.colorNeutralForeground3, fontSize: tokens.fontSizeBase200, whiteSpace: 'nowrap' },
    connector: { flexGrow: 1, height: '2px', minWidth: '16px', backgroundColor: tokens.colorNeutralStroke2, borderRadius: '1px' },
    connectorComplete: { backgroundColor: tokens.colorPaletteGreenBackground3 },
});
