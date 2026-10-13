import { Highlight } from 'prism-react-renderer';
import { makeStyles, tokens } from '@fluentui/react-components';

const useStyles = makeStyles({
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

type TokenStyle = Exclude<keyof ReturnType<typeof useStyles>, 'code' | 'line' | 'lineNumber' | 'lineContent'>;

/** Prism token type -> style. Unlisted types (plain identifiers, properties) keep the default foreground. */
const TOKEN_STYLE: Record<string, TokenStyle> = {
    comment: 'comment',
    keyword: 'keyword',
    builtin: 'keyword',
    string: 'string',
    'template-string': 'string',
    char: 'string',
    number: 'literal',
    boolean: 'literal',
    constant: 'literal',
    'class-name': 'type',
    function: 'func',
    punctuation: 'punctuation',
    operator: 'punctuation',
};

/** Files above this size are shown unhighlighted, since tokenizing runs synchronously on render. */
const MAX_HIGHLIGHT_LENGTH = 300_000;

function languageFor(path: string): string | undefined {
    if (/\.tsx?$/i.test(path)) return 'typescript';
    if (/\.json$/i.test(path)) return 'json';
    return undefined;
}

export interface ICodeViewerProps {
    code: string;
    /** File path; its extension picks the highlighting language. */
    path: string;
}

/**
 * Read-only, syntax-highlighted view of a generated file, with line numbers. The text is shown exactly as it
 * will be written; colors come from Fluent palette tokens so they follow the light/dark theme.
 */
export function CodeViewer({ code, path }: ICodeViewerProps) {
    const styles = useStyles();
    const language = languageFor(path);
    if (!language || code.length > MAX_HIGHLIGHT_LENGTH) return <pre className={styles.code}>{code}</pre>;

    return (
        <Highlight code={code.replace(/\n$/, '')} language={language}>
            {({ tokens: lines }) => (
                <pre className={styles.code}>
                    {lines.map((line, i) => (
                        <div key={i} className={styles.line}>
                            <span className={styles.lineNumber}>{i + 1}</span>
                            <span className={styles.lineContent}>
                                {line.map((token, key) => {
                                    // An empty line comes back as a single newline token; the line number already
                                    // gives the row its height, and keeping the newline would double blank lines on copy.
                                    if (token.empty) return null;
                                    // The most specific type comes last (e.g. ['class-name', 'punctuation']).
                                    const tokenStyle = [...token.types].reverse().map((t) => TOKEN_STYLE[t]).find(Boolean);
                                    return (
                                        <span key={key} className={tokenStyle ? styles[tokenStyle] : undefined}>
                                            {token.content}
                                        </span>
                                    );
                                })}
                            </span>
                        </div>
                    ))}
                </pre>
            )}
        </Highlight>
    );
}
