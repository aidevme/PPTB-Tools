import { useMemo, useState } from 'react';
import { Badge, Button, Card, CardHeader, Text, Tooltip, makeStyles, tokens } from '@fluentui/react-components';
import { DocumentSearchRegular, SaveRegular } from '@fluentui/react-icons';
import type { FileStatus, PlannedFile, WritePlan } from '../types';
import { CodeViewer } from './CodeViewer';

const useStyles = makeStyles({
    body: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalS },
    toolbar: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS, flexWrap: 'wrap' },
    counts: { display: 'flex', gap: tokens.spacingHorizontalXS, flexWrap: 'wrap' },
    split: { display: 'flex', gap: tokens.spacingHorizontalM, minHeight: '320px', maxHeight: '520px' },
    list: {
        flex: '0 0 360px',
        overflowY: 'auto',
        border: `1px solid ${tokens.colorNeutralStroke2}`,
        borderRadius: tokens.borderRadiusMedium,
    },
    file: {
        display: 'flex',
        alignItems: 'center',
        gap: tokens.spacingHorizontalS,
        padding: `${tokens.spacingVerticalXS} ${tokens.spacingHorizontalS}`,
        cursor: 'pointer',
        borderBottom: `1px solid ${tokens.colorNeutralStroke3}`,
        fontFamily: tokens.fontFamilyMonospace,
        fontSize: tokens.fontSizeBase200,
        ':hover': { backgroundColor: tokens.colorNeutralBackground1Hover },
    },
    fileSelected: { backgroundColor: tokens.colorNeutralBackground1Selected },
    fileName: { flexGrow: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' },
    viewer: {
        flexGrow: 1,
        minWidth: 0,
        border: `1px solid ${tokens.colorNeutralStroke2}`,
        borderRadius: tokens.borderRadiusMedium,
        backgroundColor: tokens.colorNeutralBackground3,
        overflow: 'auto',
        padding: tokens.spacingHorizontalS,
    },
    placeholder: { color: tokens.colorNeutralForeground3, padding: tokens.spacingVerticalL, textAlign: 'center' },
});

const STATUS_COLOR: Record<FileStatus, 'success' | 'warning' | 'informative' | 'danger'> = {
    new: 'success',
    changed: 'warning',
    unchanged: 'informative',
    orphaned: 'danger',
};

export interface PreviewCardProps {
    plan: WritePlan | null;
    /** Whether the plan is stale because the selection or options changed since it was computed. */
    stale: boolean;
    canPreview: boolean;
    /** True when everything is ready except the project folder; shows a hint next to the buttons. */
    needsProject: boolean;
    busy: boolean;
    onPreview: () => void;
    onGenerate: () => void;
}

/** Steps 4 and 5: diff the generated files against the project folder, then write them. */
export function PreviewCard({ plan, stale, canPreview, needsProject, busy, onPreview, onGenerate }: PreviewCardProps) {
    const styles = useStyles();
    const [selectedPath, setSelectedPath] = useState<string | null>(null);
    const [filter, setFilter] = useState<FileStatus | 'all'>('all');

    const files = useMemo(() => (plan ? plan.files.filter((f) => filter === 'all' || f.status === filter) : []), [plan, filter]);
    const selected: PlannedFile | undefined = plan?.files.find((f) => f.relativePath === selectedPath);
    const writable = plan ? plan.counts.new + plan.counts.changed : 0;

    return (
        <Card>
            <CardHeader
                header={
                    <Text weight="semibold" size={400}>
                        4. Preview and generate
                    </Text>
                }
                description={
                    <Text size={200}>
                        Preview loads metadata and compares the generated files with the output folder. Unchanged files are not rewritten;
                        orphaned files are reported but never deleted.
                    </Text>
                }
            />
            <div className={styles.body}>
                <div className={styles.toolbar}>
                    <Button icon={<DocumentSearchRegular />} disabled={!canPreview || busy} onClick={onPreview}>
                        Preview
                    </Button>
                    <Tooltip
                        content={plan ? `Write ${writable} file(s) and save .dataverse-gen.json` : 'Run Preview first (Regenerate in the header does both)'}
                        relationship="description"
                    >
                        <Button appearance="primary" icon={<SaveRegular />} disabled={!plan || stale || busy || writable === 0} onClick={onGenerate}>
                            Generate
                        </Button>
                    </Tooltip>
                    {needsProject && (
                        <Badge appearance="tint" color="warning">
                            Choose a project folder (step 1) to preview and generate
                        </Badge>
                    )}
                    {plan && stale && (
                        <Badge appearance="tint" color="warning">
                            Selection changed, preview again
                        </Badge>
                    )}
                    {plan && (
                        <div className={styles.counts}>
                            {(['all', 'new', 'changed', 'unchanged', 'orphaned'] as const).map((status) => (
                                <Badge
                                    key={status}
                                    appearance={filter === status ? 'filled' : 'tint'}
                                    color={status === 'all' ? 'brand' : STATUS_COLOR[status]}
                                    style={{ cursor: 'pointer' }}
                                    onClick={() => setFilter(status)}
                                >
                                    {status === 'all' ? `all ${plan.files.length}` : `${status} ${plan.counts[status]}`}
                                </Badge>
                            ))}
                        </div>
                    )}
                </div>
                {plan && (
                    <Text size={200}>
                        Output folder: <span style={{ fontFamily: tokens.fontFamilyMonospace }}>{plan.outputRoot}</span>
                    </Text>
                )}
                <div className={styles.split}>
                    <div className={styles.list}>
                        {!plan ? (
                            <div className={styles.placeholder}>No preview yet.</div>
                        ) : files.length === 0 ? (
                            <div className={styles.placeholder}>No files with this status.</div>
                        ) : (
                            files.map((file) => (
                                <div
                                    key={file.relativePath}
                                    className={`${styles.file} ${file.relativePath === selectedPath ? styles.fileSelected : ''}`}
                                    onClick={() => setSelectedPath(file.relativePath)}
                                >
                                    <Badge size="small" appearance="tint" color={STATUS_COLOR[file.status]}>
                                        {file.status}
                                    </Badge>
                                    <span className={styles.fileName} title={file.absolutePath}>
                                        {file.relativePath}
                                        {file.generatedName ? ` (generated as ${file.generatedName})` : ''}
                                    </span>
                                </div>
                            ))
                        )}
                    </div>
                    <div className={styles.viewer}>
                        {selected?.content !== undefined ? (
                            <CodeViewer code={selected.content} path={selected.relativePath} />
                        ) : selected ? (
                            <div className={styles.placeholder}>
                                This file exists in the output folder but would not be generated by the current selection. Delete it
                                manually if it is no longer needed.
                            </div>
                        ) : (
                            <div className={styles.placeholder}>Select a file to view its generated content.</div>
                        )}
                    </div>
                </div>
            </div>
        </Card>
    );
}
