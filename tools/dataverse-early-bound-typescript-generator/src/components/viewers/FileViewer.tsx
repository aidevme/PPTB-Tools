import { useEffect, useState } from 'react';
import { Badge, Button, MessageBar, MessageBarBody, Tab, TabList, Text, Tooltip } from '@fluentui/react-components';
import { CopyRegular, DocumentSearchRegular } from '@fluentui/react-icons';
import type { PlannedFile } from '../../types';
import { useFileViewerStyles } from '../../styles';
import { STATUS_META, fileName, fileType } from '../shared/generatedFiles';
import { CodeViewer } from './CodeViewer';
import { DiffViewer } from './DiffViewer';

type ViewerTab = 'changes' | 'content';

export interface IFileViewerProps {
    /** The selected file, or `null` for the empty state. */
    file: PlannedFile | null;
    /** Copies text to the clipboard; `label` names it in the confirmation. */
    onCopyText: (text: string, label: string) => void;
}

const lineCount = (text: string) => text.replace(/\r\n?/g, '\n').replace(/\n$/, '').split('\n').length;

/**
 * The right side of the Preview card: a header with the file's name, type, status, path and line count and a
 * Copy button, then either the changes Generate would make (changed files) or the generated content.
 */
export function FileViewer({ file, onCopyText }: IFileViewerProps) {
    const styles = useFileViewerStyles();
    const canDiff = file?.status === 'changed' && typeof file.existingContent === 'string' && file.content !== undefined;
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
            <div className={styles.content} role="region" aria-label={`${fileName(file.relativePath)} preview`}>
                {content === undefined ? (
                    <MessageBar intent="warning" className={styles.notice}>
                        <MessageBarBody>
                            This file is in the output folder but the current selection no longer generates it. It's only deleted when
                            Delete orphaned files is on and you confirm; otherwise remove it yourself if you no longer need it.
                        </MessageBarBody>
                    </MessageBar>
                ) : canDiff && tab === 'changes' ? (
                    <DiffViewer oldText={file.existingContent as string} newText={content} path={file.relativePath} />
                ) : (
                    <CodeViewer code={content} path={file.relativePath} />
                )}
            </div>
        </div>
    );
}
