import type { TokenStyle } from './Viewers.types';

/** Prism token type → style. Unlisted types (plain identifiers, properties) keep the default foreground. */
export const TOKEN_STYLE: Record<string, TokenStyle> = {
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
export const MAX_HIGHLIGHT_LENGTH = 300_000;

/**
 * The number of lines in `text`, counting `\r\n`, `\r` and `\n` line endings alike; a final line break doesn't start
 * another line.
 *
 * @param text - The file content.
 * @returns The line count.
 */
export const lineCount = (text: string) => text.replace(/\r\n?/g, '\n').replace(/\n$/, '').split('\n').length;
