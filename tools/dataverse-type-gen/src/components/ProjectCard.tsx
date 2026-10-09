import { Badge, Button, Card, CardHeader, Text, makeStyles, tokens } from '@fluentui/react-components';
import { ArrowClockwiseRegular, FolderOpenRegular } from '@fluentui/react-icons';
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
    configState: ProjectConfigState | null;
    busy: boolean;
    onBrowse: () => void;
    onReload: () => void;
}

/** Step 1: pick the project folder and show whether it already has a `.dataverse-gen.json`. */
export function ProjectCard({ projectRoot, configState, busy, onBrowse, onReload }: ProjectCardProps) {
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
                    {projectRoot ? <span className={styles.path}>{projectRoot}</span> : <Text italic>No project folder selected</Text>}
                </div>
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
