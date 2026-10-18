import { useEffect, useState } from 'react';
import { Badge, Button, MessageBar, MessageBarBody, Tab, TabList, Text, Tooltip } from '@fluentui/react-components';
import { CopyRegular, DocumentSearchRegular } from '@fluentui/react-icons';
import type { DuplicateIdentifier } from '../../core';
import type { PlannedFile } from '../../types';
import { writeStatusOf } from '../../services';
import { useFileViewerStyles } from '../../styles';
import { STATUS_META, fileName, fileType } from '../shared/generatedFiles';
import { CodeViewer } from './CodeViewer';
import { DiffViewer } from './DiffViewer';

type ViewerTab = 'changes' | 'content';

/** Props for {@link FileViewer}. */
export interface IFileViewerProps {
    /** The selected file, or `null` for the empty state. */
    file: PlannedFile | null;
    /**
     * Copies text to the clipboard; `label` names it in the confirmation. Called with the generated content and
     * "`<file name>` content" when the Copy button is clicked.
     */
    onCopyText: (text: string, label: string) => void;
    /**
     * Whether Generate leaves files with duplicate identifiers unwritten (Skip duplicated identifier(s)).
     * @defaultValue false
     */
    skipDuplicates?: boolean;
}

/**
 * The lines of a generated file that declare one of its duplicated identifiers (`Name = value` enum members),
 * 1-based, each with a note naming the identifier and all its values.
 *
 * @param content - The generated file's text; `undefined` for an orphaned file.
 * @param duplicates - The file's duplicated identifiers, with their values.
 * @returns The note per 1-based line number; empty when there's no content or no duplicates.
 */
export function duplicateLineNotes(content: string | undefined, duplicates: DuplicateIdentifier[] | undefined): Map<number, string> {
    const notes = new Map<number, string>();
    if (!content || !duplicates?.length) return notes;
    const byName = new Map(duplicates.map((d) => [d.name, d]));
    content.split(/\r?\n/).forEach((line, index) => {
        const name = /^\s*([A-Za-z_$][\w$]*)\s*=/.exec(line)?.[1];
        const duplicate = name !== undefined ? byName.get(name) : undefined;
        if (duplicate) notes.set(index + 1, `Duplicate identifier ${duplicate.name} (values ${duplicate.values.join(', ')})`);
    });
    return notes;
}

const lineCount = (text: string) => text.replace(/\r\n?/g, '\n').replace(/\n$/, '').split('\n').length;

/**
 * The right side of the Preview card: a header with the file's name, type, status, path and line count and a
 * Copy button, then either the changes Generate would make (changed files) or the generated content.
 */
export function FileViewer({ file, onCopyText, skipDuplicates = false }: IFileViewerProps) {
    const styles = useFileViewerStyles();
    const canDiff = !!file && writeStatusOf(file) === 'changed' && typeof file.existingContent === 'string' && file.content !== undefined;
    const [tab, setTab] = useState<ViewerTab>('changes');

    // A changed file opens on its changes; switching files resets the tab.
    useEffect(() => setTab('changes'), [file?.relativePath]);

    if (!file) {
        return (
            <div className={styles.empty}>
                <DocumentSearchRegular className={styles.emptyIcon} aria-hidden="true" />
                <Text weight="semibold">Select a file to preview it</Text>
                <Text size={200}>
                    Changed files open on what Generate would change. In the table, use <kbd className={styles.kbd}>↑</kbd>{' '}
                    <kbd className={styles.kbd}>↓</kbd> to move between files.
                </Text>
            </div>
        );
    }

    const meta = STATUS_META[file.status];
    const content = file.content;
    const lineNotes = duplicateLineNotes(content, file.duplicateIdentifiers);
    return (
        <div className={styles.root}>
            <div className={styles.header}>
                <div className={styles.headerText}>
                    <div className={styles.nameRow}>
                        <span className={styles.name}>{fileName(file.relativePath)}</span>
                        <Badge appearance="outline" size="small">
                            {fileType(file.relativePath)}
                        </Badge>
                        <Tooltip content={meta.meaning} relationship="description" withArrow>
                            <Badge appearance="tint" size="small" color={meta.color}>
                                {meta.label}
                            </Badge>
                        </Tooltip>
                    </div>
                    <Tooltip content={file.absolutePath} relationship="description" withArrow>
                        <span className={styles.path}>{file.absolutePath}</span>
                    </Tooltip>
                </div>
                {content !== undefined && <span className={styles.meta}>{lineCount(content)} lines</span>}
                {content !== undefined && (
                    <Tooltip content="Copy the generated content" relationship="label" withArrow>
                        <Button appearance="subtle" icon={<CopyRegular />} onClick={() => onCopyText(content, `${fileName(file.relativePath)} content`)} />
                    </Tooltip>
                )}
            </div>
            {canDiff && (
                <TabList className={styles.tabs} size="small" selectedValue={tab} onTabSelect={(_, data) => setTab(data.value as ViewerTab)}>
                    <Tab value="changes">Changes</Tab>
                    <Tab value="content">Generated content</Tab>
                </TabList>
            )}
            {file.duplicateIdentifiers && file.duplicateIdentifiers.length > 0 && (
                <MessageBar intent="warning" className={styles.notice}>
                    <MessageBarBody>
                        This file declares the same name more than once, so TypeScript won't compile it:{' '}
                        {file.duplicateIdentifiers.map((d, i) => (
                            <span key={d.name}>
                                {i > 0 && ', '}
                                <code>{d.name}</code> (values {d.values.join(', ')})
                            </span>
                        ))}
                        . The lines are highlighted below. Two choice labels become the same enum member name. Rename one of the labels in Dataverse, then preview again.{' '}
                        {skipDuplicates
                            ? "Skip duplicated identifier(s) is on, so Generate doesn't write it."
                            : `Generate still writes this file${writeStatusOf(file) === 'unchanged' ? ' when it changes' : ''}.`}
                    </MessageBarBody>
                </MessageBar>
            )}
            <div className={styles.content} role="region" aria-label={`${fileName(file.relativePath)} preview`}>
                {content === undefined ? (
                    <MessageBar intent="warning" className={styles.notice}>
                        <MessageBarBody>
                            This file is in the output folder but the current selection no longer generates it. It's only deleted when
                            Delete orphaned files is on and you confirm; otherwise remove it yourself if you no longer need it.
                        </MessageBarBody>
                    </MessageBar>
                ) : canDiff && tab === 'changes' ? (
                    <DiffViewer oldText={file.existingContent as string} newText={content} path={file.relativePath} lineNotes={lineNotes} />
                ) : (
                    <CodeViewer code={content} path={file.relativePath} lineNotes={lineNotes} />
                )}
            </div>
        </div>
    );
}
