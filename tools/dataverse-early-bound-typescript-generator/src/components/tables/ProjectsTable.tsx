import { Badge, Link, Table, TableBody, TableCell, TableCellLayout, TableHeader, TableRow, TableSelectionCell, Tooltip } from '@fluentui/react-components';
import { FolderRegular } from '@fluentui/react-icons';
import type { ProjectEntry } from '../../config';
import { useProjectsTableStyles, useSortableTableStyles } from '../../styles';
import { SortableHeaderCell } from './SortableHeaderCell';
import { formatDateTime } from '../shared/format';
import { activateRowOnKey } from './tableRows';
import { PROJECT_COLUMNS, type ProjectColumnKey, type ProjectSort } from './projectColumns';

/** Props for {@link ProjectsTable}. */
export interface IProjectsTableProps {
    /** The saved projects, already sorted. */
    projects: ProjectEntry[];
    /** The sorted column and direction, shown in the column headers. */
    sort: ProjectSort;
    /** Called with the column when its header is clicked, to sort by it or reverse its direction. */
    onToggleSort: (column: ProjectColumnKey) => void;
    /** Id of the selected project, whose row is highlighted and its radio checked; an empty string selects none. */
    selectedId: string;
    /** Selects a row (a click or Enter/Space on it). */
    onSelect: (project: ProjectEntry) => void;
    /** Opens a project directly (a click on its name). */
    onLoad: (project: ProjectEntry) => void;
    /** A project is being opened: the name links are disabled. */
    loading: boolean;
}

/**
 * The Load Existing Project dialog's table: one selectable row per saved project, sortable by every column. Editing
 * and deleting act on the selected row from the dialog's toolbar.
 *
 * @remarks
 * The header stays visible while the list scrolls. Each name has a folder icon, the version is a badge, the location
 * is one line cut short with the full path in a tooltip, and the dates are muted.
 */
export function ProjectsTable({ projects, sort, onToggleSort, selectedId, onSelect, onLoad, loading }: IProjectsTableProps) {
    const styles = useProjectsTableStyles();
    const tableStyles = useSortableTableStyles();
    return (
        <Table aria-label="Saved projects" size="small" sortable>
            <TableHeader>
                <TableRow className={tableStyles.headerRow}>
                    <TableSelectionCell type="radio" invisible />
                    {PROJECT_COLUMNS.map((column) => (
                        <SortableHeaderCell key={column.key} sortDirection={sort.column === column.key ? sort.direction : undefined} onClick={() => onToggleSort(column.key)}>
                            {column.label}
                        </SortableHeaderCell>
                    ))}
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
                                <TableCellLayout truncate media={<FolderRegular className={styles.folderIcon} />}>
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
                            <TableCell>
                                <Badge appearance="tint" color="informative" shape="rounded" size="medium">
                                    {project.version}
                                </Badge>
                            </TableCell>
                            <TableCell>
                                <Tooltip content={{ children: project.location, className: styles.pathTooltip }} relationship="description" withArrow>
                                    <span className={styles.path}>{project.location}</span>
                                </Tooltip>
                            </TableCell>
                            <TableCell className={styles.date}>{formatDateTime(project.createdOn)}</TableCell>
                            <TableCell className={styles.date}>{formatDateTime(project.modifiedOn)}</TableCell>
                        </TableRow>
                    );
                })}
            </TableBody>
        </Table>
    );
}
