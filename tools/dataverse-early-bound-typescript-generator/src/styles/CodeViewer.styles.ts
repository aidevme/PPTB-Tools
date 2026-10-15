import { makeStyles, tokens } from '@fluentui/react-components';

/**
 * Styles for `CodeViewer`: a monospace block laid out as a table of line-number and content cells, plus one class
 * per syntax token kind. Colours come from Fluent palette tokens, so highlighting follows the light/dark theme.
 */
export const useCodeViewerStyles = makeStyles({
    code: {
        margin: 0,
        fontFamily: tokens.fontFamilyMonospace,
        fontSize: tokens.fontSizeBase200,
        lineHeight: tokens.lineHeightBase200,
        whiteSpace: 'pre',
        color: tokens.colorNeutralForeground1,
    },
    line: { display: 'table-row' },
    lineNumber: {
        display: 'table-cell',
        textAlign: 'right',
        paddingRight: tokens.spacingHorizontalM,
        color: tokens.colorNeutralForeground4,
        userSelect: 'none',
    },
    lineContent: { display: 'table-cell' },
    comment: { color: tokens.colorNeutralForeground3, fontStyle: 'italic' },
    keyword: { color: tokens.colorPaletteBlueForeground2 },
    string: { color: tokens.colorPaletteDarkOrangeForeground2 },
    literal: { color: tokens.colorPaletteGreenForeground2 },
    type: { color: tokens.colorPaletteTealForeground2 },
    func: { color: tokens.colorPaletteMarigoldForeground2 },
    punctuation: { color: tokens.colorNeutralForeground2 },
});
