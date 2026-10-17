/** The Preview card's sortable file table: name (with type icon), type and status; a row selects its file for the viewer. */
import { useRef, type KeyboardEvent } from 'react';
import { Table, TableBody, TableCell, TableCellLayout, TableHeader, TableRow, Tooltip, mergeClasses, type SortDirection } from '@fluentui/react-components';
import { CodeTextRegular, DatabaseRegular, DocumentRegular, FlashRegular, MathFormulaRegular, TableRegular, TextBulletListLtrRegular } from '@fluentui/react-icons';
import type { FileStatus, PlannedFile } from '../../types';
import { usePreviewCardStyles, useSortableTableStyles } from '../../styles';
import { STATUS_META, fileName, fileType, type GeneratedFileType } from '../shared/generatedFiles';
import { HEADER_HELP, type FileSortColumn } from '../shared/previewFiles';
import { SortableHeaderCell } from '../shared/SortableHeaderCell';
import { activateRowOnKey } from '../shared/tableRows';

type PreviewCardStyles = ReturnType<typeof usePreviewCardStyles>;

const TYPE_ICONS: Record<GeneratedFileType, JSX.Element> = {
    entities: <TableRegular />,
    enums: <TextBulletListLtrRegular />,
    actions: <FlashRegular />,
    functions: <MathFormulaRegular />,
    metadata: <DatabaseRegular />,
    templates: <CodeTextRegular />,
    other: <DocumentRegular />,
};

/** The file table's status dot class, per status. */
const STATUS_DOT: Record<FileStatus, keyof PreviewCardStyles> = {
    new: 'dotNew',
    changed: 'dotChanged',
    unchanged: 'dotUnchanged',
    orphaned: 'dotOrphaned',
    duplicate: 'dotDuplicate',
};

export interface IFileTableProps {
    /** The files to list, already filtered and sorted. */
    files: PlannedFile[];
    selectedPath: string | null;
    onSelect: (relativePath: string) => void;
    /** The sort direction of `column`, or `undefined` when it isn't the sorted column. */
    sortDirection: (column: FileSortColumn) => SortDirection | undefined;
    onToggleSort: (column: FileSortColumn) => void;
}

/** The sortable file table: name (with type icon), type and status; a row selects its file for the viewer. */
export function FileTable({ files, selectedPath, onSelect, sortDirection, onToggleSort }: IFileTableProps) {
    const styles = usePreviewCardStyles();
    const tableStyles = useSortableTableStyles();
    const tableRef = useRef<HTMLTableElement>(null);

    /** ↑/↓ move the selection to the neighbouring row and focus it. */
    const onRowKeyDown = (e: KeyboardEvent, index: number) => {
        if (activateRowOnKey(e, () => onSelect(files[index].relativePath))) return;
        const target = e.key === 'ArrowDown' ? index + 1 : e.key === 'ArrowUp' ? index - 1 : -1;
        if (target >= 0 && target < files.length) {
            e.preventDefault();
            onSelect(files[target].relativePath);
            tableRef.current?.querySelectorAll<HTMLElement>('tbody tr')[target]?.focus();
        }
    };

    return (
        <Table aria-label="Generated files" size="extra-small" sortable ref={tableRef}>
            <TableHeader>
                <TableRow className={tableStyles.headerRow}>
                    {(
                        [
                            ['name', 'Name', undefined],
                            ['type', 'Type', styles.typeColumn],
                            ['status', 'Status', styles.statusColumn],
                        ] as const
                    ).map(([column, label, widthClass]) => (
                        <SortableHeaderCell key={column} help={HEADER_HELP[column]} className={widthClass} sortDirection={sortDirection(column)} onClick={() => onToggleSort(column)}>
                            {label}
                        </SortableHeaderCell>
                    ))}
                </TableRow>
            </TableHeader>
            <TableBody>
                {files.map((file, index) => {
                    const isSelected = file.relativePath === selectedPath;
                    const type = fileType(file.relativePath);
                    return (
                        <TableRow
                            key={file.relativePath}
                            className={tableStyles.row}
                            aria-selected={isSelected}
                            appearance={isSelected ? 'brand' : 'none'}
                            tabIndex={0}
                            onClick={() => onSelect(file.relativePath)}
                            onKeyDown={(e) => onRowKeyDown(e, index)}
                        >
                            <TableCell>
                                <TableCellLayout truncate media={<span className={styles.typeIcon}>{TYPE_ICONS[type]}</span>}>
                                    <Tooltip content={file.absolutePath} relationship="description" withArrow>
                                        <span className={styles.fileName}>
                                            {fileName(file.relativePath)}
                                            {file.generatedName ? ` (generated as ${file.generatedName})` : ''}
                                        </span>
                                    </Tooltip>
                                </TableCellLayout>
                            </TableCell>
                            <TableCell className={styles.typeColumn}>{type}</TableCell>
                            <TableCell className={styles.statusColumn}>
                                <span className={styles.status}>
                                    <span className={mergeClasses(styles.dot, styles[STATUS_DOT[file.status]])} aria-hidden="true" />
                                    {STATUS_META[file.status].label.toLowerCase()}
                                </span>
                            </TableCell>
                        </TableRow>
                    );
                })}
            </TableBody>
        </Table>
    );
}
