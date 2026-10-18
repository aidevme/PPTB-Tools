import type { ReactNode } from 'react';
import { Highlight } from 'prism-react-renderer';
import { mergeClasses } from '@fluentui/react-components';
import { useCodeViewerStyles } from '../../styles';

type TokenStyle = Exclude<keyof ReturnType<typeof useCodeViewerStyles>, 'code' | 'line' | 'lineNumber' | 'lineContent' | 'flagged' | 'flaggedNumber'>;

/** Prism token type → style. Unlisted types (plain identifiers, properties) keep the default foreground. */
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
    // dataverse-gen's EJS templates produce TypeScript, so most of their text is TypeScript; the <% %> tags show in the
    // punctuation color.
    if (/\.ejs$/i.test(path)) return 'typescript';
    return undefined;
}

/** Props for {@link CodeViewer}. */
export interface ICodeViewerProps {
    /** The file's text; CRLF and CR line endings are shown as plain line breaks, and a final newline is dropped. */
    code: string;
    /** File path; its extension picks the highlighting language. */
    path: string;
    /** Lines to highlight (1-based), each with the note shown when hovering over it. */
    lineNotes?: ReadonlyMap<number, string>;
}

/**
 * Read-only, syntax-highlighted view of a generated file, with line numbers. The text is shown as it will be written
 * (CRLF line endings appear as plain line breaks); colors come from Fluent palette tokens so they follow the
 * light/dark theme. Files in a language without highlighting, or too large to tokenize, still get line numbers.
 */
export function CodeViewer({ code, path, lineNotes }: ICodeViewerProps) {
    const styles = useCodeViewerStyles();
    const language = languageFor(path);
    const text = code.replace(/\r\n?/g, '\n').replace(/\n$/, '');

    /** One numbered row, flagged with its note when `lineNotes` has one. */
    const row = (i: number, content: ReactNode) => {
        const note = lineNotes?.get(i + 1);
        return (
            <div
                key={i}
                className={mergeClasses(styles.line, note !== undefined && styles.flagged)}
                title={note}
                data-flagged={note !== undefined || undefined}
            >
                <span className={mergeClasses(styles.lineNumber, note !== undefined && styles.flaggedNumber)}>{i + 1}</span>
                <span className={styles.lineContent}>{content}</span>
            </div>
        );
    };

    if (!language || code.length > MAX_HIGHLIGHT_LENGTH) {
        return <pre className={styles.code}>{text.split('\n').map((line, i) => row(i, line))}</pre>;
    }

    return (
        <Highlight code={text} language={language}>
            {({ tokens: lines }) => (
                <pre className={styles.code}>
                    {lines.map((line, i) =>
                        row(
                            i,
                            line.map((token, key) => {
                                // An empty line comes back as a single newline token; the line number already gives the
                                // row its height, and keeping the newline would double blank lines on copy.
                                if (token.empty) return null;
                                // The most specific type comes last (e.g. ['class-name', 'punctuation']).
                                const tokenStyle = [...token.types].reverse().map((t) => TOKEN_STYLE[t]).find(Boolean);
                                return (
                                    <span key={key} className={tokenStyle ? styles[tokenStyle] : undefined}>
                                        {token.content}
                                    </span>
                                );
                            }),
                        ),
                    )}
                </pre>
            )}
        </Highlight>
    );
}
