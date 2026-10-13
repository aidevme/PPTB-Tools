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
}

/**
 * The lines Generate would change in a file: removed lines in red, added lines in green, both line numbers in
 * the gutter, and long unchanged stretches collapsed. Very large rewrites fall back to the full new content.
 */
export function DiffViewer({ oldText, newText, path }: IDiffViewerProps) {
    const styles = useFileViewerStyles();
    const result = useMemo(() => diffLines(oldText, newText), [oldText, newText]);

    if (!result) {
        return (
            <>
                <MessageBar intent="info" className={styles.notice}>
                    <MessageBarBody>Too many changes to compare line by line; showing the new content.</MessageBarBody>
                </MessageBar>
                <CodeViewer code={newText} path={path} />
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
                            const tint = line.kind === 'add' ? styles.diffAdd : line.kind === 'remove' ? styles.diffRemove : undefined;
                            return (
                                <div key={i} role="row" className={styles.diffRow}>
                                    <span className={mergeClasses(styles.gutter, tint)} role="cell">
                                        {line.oldNumber ?? ''}
                                    </span>
                                    <span className={mergeClasses(styles.gutter, tint)} role="cell">
                                        {line.newNumber ?? ''}
                                    </span>
                                    <span
                                        className={mergeClasses(styles.sign, tint, line.kind === 'add' && styles.signAdd, line.kind === 'remove' && styles.signRemove)}
                                        role="cell"
                                        aria-label={line.kind === 'add' ? 'added' : line.kind === 'remove' ? 'removed' : 'unchanged'}
                                    >
                                        {line.kind === 'add' ? '+' : line.kind === 'remove' ? '−' : ' '}
                                    </span>
                                    <span className={mergeClasses(styles.code, tint)} role="cell">
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
