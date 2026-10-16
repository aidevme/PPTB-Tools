import { Fragment, useMemo } from 'react';
import { MessageBar, MessageBarBody, mergeClasses } from '@fluentui/react-components';
import { useFileViewerStyles } from '../../styles';
import { diffLines } from '../shared/lineDiff';
import { CodeViewer } from './CodeViewer';

export interface IDiffViewerProps {
    /** What's on disk now. */
    oldText: string;
    /** What Generate would write. */
    newText: string;
    /** File path, for highlighting when falling back to the full content. */
    path: string;
    /** Lines of the new text to highlight (1-based), each with the note shown when hovering over it. */
    lineNotes?: ReadonlyMap<number, string>;
}

/**
 * The lines Generate would change in a file: removed lines in red, added lines in green, both line numbers in
 * the gutter, and long unchanged stretches collapsed. Very large rewrites fall back to the full new content.
 */
export function DiffViewer({ oldText, newText, path, lineNotes }: IDiffViewerProps) {
    const styles = useFileViewerStyles();
    const result = useMemo(() => diffLines(oldText, newText), [oldText, newText]);

    if (!result) {
        return (
            <>
                <MessageBar intent="info" className={styles.notice}>
                    <MessageBarBody>Too many changes to compare line by line; showing the new content.</MessageBarBody>
                </MessageBar>
                <CodeViewer code={newText} path={path} lineNotes={lineNotes} />
            </>
        );
    }
    if (result.added + result.removed === 0) {
        return (
            <MessageBar intent="info" className={styles.notice}>
                <MessageBarBody>Only the final newline differs.</MessageBarBody>
            </MessageBar>
        );
    }

    return (
        <div className={styles.diff} role="table" aria-label={`Changes: ${result.added} added, ${result.removed} removed`}>
            {result.blocks.map((block, b) =>
                block.kind === 'skipped' ? (
                    <div key={b} className={styles.diffRow} role="row">
                        <span className={styles.skipped} role="cell">
                            ··· {block.count} unchanged {block.count === 1 ? 'line' : 'lines'}
                        </span>
                    </div>
                ) : (
                    <Fragment key={b}>
                        {block.lines.map((line, i) => {
                            const note = line.newNumber !== undefined ? lineNotes?.get(line.newNumber) : undefined;
                            const tint = mergeClasses(
                                line.kind === 'add' ? styles.diffAdd : line.kind === 'remove' ? styles.diffRemove : undefined,
                                note !== undefined && styles.diffFlagged,
                            );
                            return (
                                <div key={i} role="row" className={styles.diffRow} title={note} data-flagged={note !== undefined || undefined}>
                                    <span className={mergeClasses(styles.gutter, tint)} role="cell">
                                        {line.oldNumber ?? ''}
                                    </span>
                                    <span className={mergeClasses(styles.gutter, tint, note !== undefined && styles.diffFlaggedNumber)} role="cell">
                                        {line.newNumber ?? ''}
                                    </span>
                                    <span
                                        className={mergeClasses(styles.sign, tint, line.kind === 'add' && styles.signAdd, line.kind === 'remove' && styles.signRemove)}
                                        role="cell"
                                        aria-label={line.kind === 'add' ? 'added' : line.kind === 'remove' ? 'removed' : 'unchanged'}
                                    >
                                        {line.kind === 'add' ? '+' : line.kind === 'remove' ? '−' : ' '}
                                    </span>
                                    <span className={mergeClasses(styles.code, tint)} role="cell" title={note}>
                                        {line.text}
                                    </span>
                                </div>
                            );
                        })}
                    </Fragment>
                ),
            )}
        </div>
    );
}
