import {
    Badge,
    Button,
    Card,
    CardHeader,
    Menu,
    MenuButton,
    MenuDivider,
    MenuItem,
    MenuList,
    MenuPopover,
    MenuTrigger,
    Text,
    makeStyles,
    tokens,
} from '@fluentui/react-components';
import { ArrowClockwiseRegular, CopyRegular, DismissCircleRegular, DocumentRegular, FolderOpenRegular, FolderRegular } from '@fluentui/react-icons';
import type { ProjectConfigState } from '../services/projectConfig';

const useStyles = makeStyles({
    body: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalS },
    row: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS, flexWrap: 'wrap' },
    path: {
        fontFamily: tokens.fontFamilyMonospace,
        fontSize: tokens.fontSizeBase200,
        padding: `${tokens.spacingVerticalXS} ${tokens.spacingHorizontalS}`,
        backgroundColor: tokens.colorNeutralBackground3,
        borderRadius: tokens.borderRadiusMedium,
        wordBreak: 'break-all',
        flexGrow: 1,
    },
});

export interface ProjectCardProps {
    projectRoot: string | null;
    /** Folder used last time; PPTB needs it re-selected through Browse before it can be read. */
    rememberedFolder: string | null;
    configState: ProjectConfigState | null;
    busy: boolean;
    onBrowse: () => void;
    onReload: () => void;
    /** Absolute output folder (`output.outputRoot` resolved against the project), when a project is open. */
    outputFolder: string | null;
    /** Whether anything is selected, enabling "Clear selection". */
    hasSelection: boolean;
    onCopyPath: (path: string, label: string) => void;
    onClearSelection: () => void;
}

/** Step 1: pick the project folder and show whether it already has a `.dataverse-gen.json`. */
export function ProjectCard({
    projectRoot,
    rememberedFolder,
    configState,
    busy,
    onBrowse,
    onReload,
    outputFolder,
    hasSelection,
    onCopyPath,
    onClearSelection,
}: ProjectCardProps) {
    const styles = useStyles();
    const config = configState?.config;
    const counts = config
        ? `${config.entities?.length ?? 0} tables, ${config.actions?.length ?? 0} actions, ${config.functions?.length ?? 0} functions`
        : '';
    return (
        <Card>
            <CardHeader
                header={
                    <Text weight="semibold" size={400}>
                        1. Project
                    </Text>
                }
                description={<Text size={200}>The folder that contains (or will contain) .dataverse-gen.json, usually your package.json folder.</Text>}
            />
            <div className={styles.body}>
                <div className={styles.row}>
                    <Button icon={<FolderOpenRegular />} onClick={onBrowse} disabled={busy}>
                        Browse…
                    </Button>
                    <Button icon={<ArrowClockwiseRegular />} appearance="subtle" onClick={onReload} disabled={busy || !projectRoot}>
                        Reload config
                    </Button>
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
                    {projectRoot ? <span className={styles.path}>{projectRoot}</span> : <Text italic>No project folder selected</Text>}
                </div>
                {!projectRoot && rememberedFolder && (
                    <Text size={200}>
                        Last used: <span className={styles.path}>{rememberedFolder}</span> Click Browse… to reopen it (the folder picker opens
                        there, and PPTB needs you to confirm it before the tool can read it).
                    </Text>
                )}
                {configState && (
                    <div className={styles.row}>
                        {configState.exists ? (
                            <>
                                <Badge appearance="tint" color="success">
                                    .dataverse-gen.json found
                                </Badge>
                                <Text size={200}>{counts}</Text>
                            </>
                        ) : (
                            <>
                                <Badge appearance="tint" color="informative">
                                    New project
                                </Badge>
                                <Text size={200}>.dataverse-gen.json will be created on generate.</Text>
                            </>
                        )}
                    </div>
                )}
            </div>
        </Card>
    );
}
