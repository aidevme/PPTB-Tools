import type { MouseEvent, ReactElement } from 'react';
import { Button, Link, Table, TableBody, TableCell, TableCellLayout, TableHeader, TableHeaderCell, TableRow, TableSelectionCell, Tooltip } from '@fluentui/react-components';
import { DeleteRegular, EditRegular } from '@fluentui/react-icons';
import type { ProjectEntry } from '../../config';
import { useLoadProjectDialogStyles, useSortableTableStyles } from '../../styles';
import { SortableHeaderCell } from './SortableHeaderCell';
import { formatDateTime } from '../shared/format';
import { activateRowOnKey } from './tableRows';
import { PROJECT_COLUMNS, type ProjectColumnKey, type ProjectSort } from './projectColumns';

export interface IProjectsTableProps {
    /** The saved projects, already sorted. */
    projects: ProjectEntry[];
    sort: ProjectSort;
    onToggleSort: (column: ProjectColumnKey) => void;
    selectedId: string;
    /** Selects a row (a click or Enter/Space on it). */
    onSelect: (project: ProjectEntry) => void;
    /** Opens a project directly (a click on its name). */
    onLoad: (project: ProjectEntry) => void;
    onEdit: (project: ProjectEntry) => void;
    onDelete: (project: ProjectEntry) => void;
    /** A project is being opened: the name links are disabled. */
    loading: boolean;
    /** Opening or deleting: the row actions are disabled. */
    busy: boolean;
}

/** An icon-only row action. Its click and keys don't reach the row, so they don't select it. */
function RowActionButton({ tooltip, label, icon, disabled, onClick }: { tooltip: string; label: string; icon: ReactElement; disabled: boolean; onClick: () => void }) {
    return (
        <Tooltip content={tooltip} relationship="label" withArrow>
            <Button
                appearance="subtle"
                icon={icon}
                aria-label={label}
                disabled={disabled}
                onClick={(e: MouseEvent) => {
                    e.stopPropagation();
                    onClick();
                }}
                onKeyDown={(e) => e.stopPropagation()}
            />
        </Tooltip>
    );
}

/** The Load Existing Project dialog's table: one selectable row per saved project, sortable by every column. */
export function ProjectsTable({ projects, sort, onToggleSort, selectedId, onSelect, onLoad, onEdit, onDelete, loading, busy }: IProjectsTableProps) {
    const styles = useLoadProjectDialogStyles();
    const tableStyles = useSortableTableStyles();
    return (
        <Table aria-label="Saved projects" size="small" sortable>
            <TableHeader>
                <TableRow>
                    <TableSelectionCell type="radio" invisible />
                    {PROJECT_COLUMNS.map((column) => (
                        <SortableHeaderCell key={column.key} sortDirection={sort.column === column.key ? sort.direction : undefined} onClick={() => onToggleSort(column.key)}>
                            {column.label}
                        </SortableHeaderCell>
                    ))}
                    <TableHeaderCell className={styles.actionsCell} aria-label="Actions" />
                </TableRow>
            </TableHeader>
            <TableBody>
                {projects.map((project) => {
                    const isSelected = project.id === selectedId;
                    return (
                        <TableRow
                            key={project.id}
                            className={tableStyles.row}
                            aria-selected={isSelected}
                            appearance={isSelected ? 'brand' : 'none'}
                            tabIndex={0}
                            onClick={() => onSelect(project)}
                            onKeyDown={(e) => activateRowOnKey(e, () => onSelect(project))}
                        >
                            <TableSelectionCell type="radio" checked={isSelected} radioIndicator={{ 'aria-label': `Select ${project.name}` }} />
                            <TableCell>
                                <TableCellLayout truncate>
                                    <Link
                                        disabled={loading}
                                        onClick={(e) => {
                                            e.stopPropagation();
                                            onLoad(project);
                                        }}
                                    >
                                        {project.name}
                                    </Link>
                                </TableCellLayout>
                            </TableCell>
                            <TableCell>
                                {project.description ? (
                                    <Tooltip content={{ children: project.description, className: styles.descriptionTooltip }} relationship="description" withArrow>
                                        <TableCellLayout truncate>{project.description}</TableCellLayout>
                                    </Tooltip>
                                ) : (
                                    <TableCellLayout truncate>
                                        <span className={styles.muted}>—</span>
                                    </TableCellLayout>
                                )}
                            </TableCell>
                            <TableCell>{project.version}</TableCell>
                            <TableCell>
                                <Tooltip content={project.location} relationship="description" withArrow>
                                    <span className={styles.path}>{project.location}</span>
                                </Tooltip>
                            </TableCell>
                            <TableCell>{formatDateTime(project.createdOn)}</TableCell>
                            <TableCell>{formatDateTime(project.modifiedOn)}</TableCell>
                            <TableCell className={styles.actionsCell}>
                                <RowActionButton tooltip="Edit project" label={`Edit ${project.name}`} icon={<EditRegular />} disabled={busy} onClick={() => onEdit(project)} />
                                <RowActionButton tooltip="Delete project" label={`Delete ${project.name}`} icon={<DeleteRegular />} disabled={busy} onClick={() => onDelete(project)} />
                            </TableCell>
                        </TableRow>
                    );
                })}
            </TableBody>
        </Table>
    );
}
