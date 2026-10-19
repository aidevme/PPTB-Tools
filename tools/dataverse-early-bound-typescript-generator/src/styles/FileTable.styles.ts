import { makeStyles, tokens } from '@fluentui/react-components';

/** Styles for `FileTable`: the type and status column widths, the file name, the type icon and the status dots. */
export const useFileTableStyles = makeStyles({
    typeColumn: { width: '104px' },
    statusColumn: { width: '112px' },
    fileName: { fontFamily: tokens.fontFamilyMonospace, fontSize: tokens.fontSizeBase200 },
    typeIcon: { color: tokens.colorBrandForeground1 },
    status: { display: 'inline-flex', alignItems: 'center', gap: tokens.spacingHorizontalXS, fontSize: tokens.fontSizeBase200, whiteSpace: 'nowrap' },
    dot: { width: '8px', height: '8px', borderRadius: tokens.borderRadiusCircular, flexShrink: 0 },
    dotNew: { backgroundColor: tokens.colorPaletteGreenForeground1 },
    dotChanged: { backgroundColor: tokens.colorPaletteMarigoldForeground1 },
    dotUnchanged: { backgroundColor: tokens.colorNeutralForeground4 },
    dotOrphaned: { backgroundColor: tokens.colorPaletteRedForeground1 },
    dotDuplicate: { backgroundColor: tokens.colorPaletteDarkOrangeForeground1 },
});
