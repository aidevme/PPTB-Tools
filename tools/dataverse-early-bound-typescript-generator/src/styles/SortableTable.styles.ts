import { makeStyles, tokens } from '@fluentui/react-components';

/** Shared by the sortable tables (Select card, Preview card, Load Existing Project dialog) and `SortableHeaderCell`. */
export const useSortableTableStyles = makeStyles({
    row: { cursor: 'pointer' },
    // Keeps the column headers visible while the list scrolls.
    headerRow: { position: 'sticky', top: 0, zIndex: 1, backgroundColor: tokens.colorNeutralBackground1 },
    headerCell: { fontWeight: tokens.fontWeightSemibold },
    // Wider than Fluent's default tooltip, for the per-value explanations.
    headerTooltip: { maxWidth: '360px', '& ul': { margin: `${tokens.spacingVerticalXS} 0`, paddingLeft: tokens.spacingHorizontalL } },
});
