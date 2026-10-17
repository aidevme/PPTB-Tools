import { Text, Tooltip } from '@fluentui/react-components';
import { FolderRegular, HistoryRegular } from '@fluentui/react-icons';
import { useRecentProjectsListStyles } from '../../styles';
import type { ProjectOpenTarget, RecentProject } from './recentProjects';

export interface IRecentProjectsListProps {
    /** "Recent projects", or "Switch to a recent project" while one is open. */
    heading: string;
    items: RecentProject[];
    busy: boolean;
    onOpen: (target: ProjectOpenTarget) => void;
}

/** The Project card's recent projects: one button per project, with its full path in a tooltip. */
export function RecentProjectsList({ heading, items, busy, onOpen }: IRecentProjectsListProps) {
    const styles = useRecentProjectsListStyles();
    if (items.length === 0) return null;
    return (
        <div className={styles.root}>
            <Text size={200} className={styles.heading}>
                {heading}
            </Text>
            <ul className={styles.list}>
                {items.map((item) => (
                    <li key={item.key}>
                        <Tooltip content={item.location} relationship="description" withArrow>
                            <button
                                type="button"
                                className={styles.item}
                                disabled={busy}
                                aria-label={`Open ${item.name} (${item.meta})`}
                                onClick={() => onOpen({ name: item.name, location: item.location })}
                            >
                                {item.isLastUsed ? <HistoryRegular className={styles.icon} /> : <FolderRegular className={styles.icon} />}
                                <span className={styles.text}>
                                    <span className={styles.name}>{item.name}</span>
                                    <span className={styles.meta}>{item.meta}</span>
                                </span>
                            </button>
                        </Tooltip>
                    </li>
                ))}
            </ul>
        </div>
    );
}
