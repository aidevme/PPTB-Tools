import {
    Badge,
    Button,
    Menu,
    MenuButton,
    MenuDivider,
    MenuItem,
    MenuList,
    MenuPopover,
    MenuTrigger,
    Text,
    Tooltip,
} from '@fluentui/react-components';
import {
    AddRegular,
    ArrowClockwiseRegular,
    CopyRegular,
    DismissCircleRegular,
    DocumentAddRegular,
    DocumentCheckmarkRegular,
    DocumentRegular,
    FolderAddRegular,
    FolderListRegular,
    FolderOpenRegular,
    FolderRegular,
} from '@fluentui/react-icons';
import type { ProjectEntry } from '../../config';
import { basename, isSamePath, type ProjectConfigState } from '../../services';
import { useProjectCardStyles } from '../../styles';
import { formatRelativeTime } from '../shared/format';
import { PathChip } from '../shared/PathChip';
import { StepCard } from '../shared/StepCard';
import type { StepState } from '../shared/workflowSteps';
import { RecentProjectsList } from './RecentProjectsList';
import { MAX_RECENT, recentProjects, type ProjectOpenTarget } from './recentProjects';

/** Temporarily hidden; set to `true` to show the History menu (copy paths, clear selection) again. */
const SHOW_HISTORY_MENU = false;

export interface ProjectCardProps {
    step: StepState;
    projectRoot: string | null;
    /** Folder used last time with this connection, offered first for reopening while no project is open. */
    rememberedFolder: string | null;
    configState: ProjectConfigState | null;
    /** Saved projects, for the open project's name and version and for the recent-projects list. */
    projects: ProjectEntry[];
    /** How many recent projects to offer (the General setting); 0 hides the list. Defaults to 3. */
    recentProjectCount?: number;
    busy: boolean;
    /** Opens the New Project dialog. */
    onNewProject: () => void;
    /** Opens the Load Existing Project dialog. */
    onLoadExistingProject: () => void;
    /** Opens a recent project directly. */
    onOpenRecent: (target: ProjectOpenTarget) => void;
    onReload: () => void;
    /** Absolute output folder (`output.outputRoot` resolved against the project), when a project is open. */
    outputFolder: string | null;
    /** Whether anything is selected, enabling "Clear selection". */
    hasSelection: boolean;
    onCopyPath: (path: string, label: string) => void;
    onClearSelection: () => void;
    /** Current time for relative dates; a parameter so tests get stable output. */
    now?: number;
}

/**
 * Step 1: open a project. Without one, an empty state with the main actions and recent projects; with one, a
 * summary of the project (name, version, path, config status and selection counts).
 */
export function ProjectCard(props: ProjectCardProps) {
    const { step, projectRoot, configState, projects, busy, onNewProject, onLoadExistingProject, onOpenRecent, onReload, onCopyPath } = props;
    const styles = useProjectCardStyles();
    const now = props.now ?? Date.now();
    const recent = recentProjects(projects, projectRoot, props.rememberedFolder, now, props.recentProjectCount ?? MAX_RECENT);

    return (
        <StepCard step={step} description="The folder that contains (or will contain) .dataverse-gen.json, usually your package.json folder.">
            <div className={styles.body}>
                {projectRoot ? (
                    renderSummary(projectRoot)
                ) : (
                    <div className={styles.empty} key="empty">
                        <FolderOpenRegular className={styles.emptyIcon} aria-hidden="true" />
                        <div className={styles.emptyText}>
                            <Text weight="semibold" size={400}>
                                Open a project to get started
                            </Text>
                            <Text size={200} className={styles.muted}>
                                Load a saved project, or create one for a folder that has, or will have, a .dataverse-gen.json.
                            </Text>
                        </div>
                        <div className={styles.emptyActions}>
                            <Button appearance="primary" icon={<FolderListRegular />} onClick={onLoadExistingProject} disabled={busy}>
                                Load Existing Project
                            </Button>
                            <Button icon={<AddRegular />} onClick={onNewProject} disabled={busy}>
                                New Project
                            </Button>
                        </div>
                    </div>
                )}
                <RecentProjectsList heading={projectRoot ? 'Switch to a recent project' : 'Recent projects'} items={recent} busy={busy} onOpen={onOpenRecent} />
                {SHOW_HISTORY_MENU && <HistoryMenu {...props} />}
            </div>
        </StepCard>
    );

    // A render function rather than a nested component, so React doesn't remount the summary on every render.
    function renderSummary(root: string) {
        const saved = projects.find((p) => isSamePath(p.location, root));
        const config = configState?.config;
        const counts = config
            ? [
                  `${config.entities?.length ?? 0} tables`,
                  `${config.actions?.length ?? 0} actions`,
                  `${config.functions?.length ?? 0} functions`,
              ]
            : [];
        return (
            <div className={styles.summary} key={`open:${root}`}>
                <FolderRegular className={styles.summaryIcon} aria-hidden="true" />
                <div className={styles.summaryText}>
                    <div className={styles.nameRow}>
                        <Text as="h3" className={styles.name}>
                            {saved?.name ?? (basename(root) || root)}
                        </Text>
                        {saved && (
                            <Badge appearance="outline" color="brand">
                                v{saved.version}
                            </Badge>
                        )}
                    </div>
                    <div className={styles.pathRow}>
                        <PathChip path={root} label="Project folder path" onCopy={onCopyPath} />
                    </div>
                    <div className={styles.row}>
                        {configState &&
                            (configState.exists ? (
                                <Badge appearance="tint" color="success" icon={<DocumentCheckmarkRegular />}>
                                    .dataverse-gen.json found
                                </Badge>
                            ) : (
                                <Badge appearance="tint" color="informative" icon={<DocumentAddRegular />}>
                                    New project: created on generate
                                </Badge>
                            ))}
                        {counts.map((c) => (
                            <Badge key={c} appearance="tint" color="subtle">
                                {c}
                            </Badge>
                        ))}
                    </div>
                    {saved && (
                        <Text size={200} className={styles.muted}>
                            Modified {formatRelativeTime(saved.modifiedOn, now)}
                        </Text>
                    )}
                </div>
                <div className={styles.summaryActions}>
                    <Tooltip content="Reload .dataverse-gen.json from disk" relationship="label" withArrow>
                        <Button appearance="subtle" icon={<ArrowClockwiseRegular />} onClick={onReload} disabled={busy} />
                    </Tooltip>
                    <Button icon={<FolderListRegular />} onClick={onLoadExistingProject} disabled={busy}>
                        Load Existing Project
                    </Button>
                    <Button appearance="subtle" icon={<FolderAddRegular />} onClick={onNewProject} disabled={busy}>
                        New Project
                    </Button>
                </div>
            </div>
        );
    }
}

/** Copy-path and clear-selection actions; hidden while `SHOW_HISTORY_MENU` is `false`. */
function HistoryMenu({ projectRoot, configState, outputFolder, hasSelection, busy, onCopyPath, onClearSelection }: ProjectCardProps) {
    return (
        <Menu>
            <MenuTrigger disableButtonEnhancement>
                <MenuButton appearance="subtle" disabled={busy}>
                    History
                </MenuButton>
            </MenuTrigger>
            <MenuPopover>
                <MenuList>
                    <MenuItem icon={<FolderRegular />} disabled={!projectRoot} onClick={() => projectRoot && onCopyPath(projectRoot, 'Project folder path')}>
                        Copy project folder path
                    </MenuItem>
                    <MenuItem
                        icon={<DocumentRegular />}
                        disabled={!configState?.path}
                        onClick={() => configState?.path && onCopyPath(configState.path, '.dataverse-gen.json path')}
                    >
                        Copy .dataverse-gen.json path
                    </MenuItem>
                    <MenuItem icon={<CopyRegular />} disabled={!outputFolder} onClick={() => outputFolder && onCopyPath(outputFolder, 'Output folder path')}>
                        Copy output folder path
                    </MenuItem>
                    <MenuDivider />
                    <MenuItem icon={<DismissCircleRegular />} disabled={!hasSelection} onClick={onClearSelection}>
                        Clear selection
                    </MenuItem>
                </MenuList>
            </MenuPopover>
        </Menu>
    );
}
