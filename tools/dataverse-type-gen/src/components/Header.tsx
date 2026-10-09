import { Badge, Button, Text, Tooltip, makeStyles, tokens } from '@fluentui/react-components';
import { ArrowSyncRegular } from '@fluentui/react-icons';

const useStyles = makeStyles({
    header: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: tokens.spacingHorizontalM,
        padding: `${tokens.spacingVerticalM} ${tokens.spacingHorizontalL}`,
        borderBottom: `1px solid ${tokens.colorNeutralStroke2}`,
        flexWrap: 'wrap',
    },
    titleBlock: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalXXS },
    right: { display: 'flex', alignItems: 'center', gap: tokens.spacingHorizontalS },
});

export interface HeaderProps {
    connection: ToolBoxAPI.Connection | null;
    /** Whether a `.dataverse-gen.json` with a selection is loaded, enabling one-click regeneration. */
    canRegenerate: boolean;
    busy: boolean;
    onRegenerate: () => void;
}

/** Tool title, active connection badge and the one-click Regenerate action. */
export function Header({ connection, canRegenerate, busy, onRegenerate }: HeaderProps) {
    const styles = useStyles();
    return (
        <header className={styles.header}>
            <div className={styles.titleBlock}>
                <Text size={600} weight="semibold">
                    Dataverse Type Forge
                </Text>
                <Text size={200}>Early-bound TypeScript types and metadata for dataverse-ify, from a .dataverse-gen.json project.</Text>
            </div>
            <div className={styles.right}>
                {connection ? (
                    <Tooltip content={connection.url} relationship="description">
                        <Badge appearance="tint" color="brand">
                            {connection.name}
                        </Badge>
                    </Tooltip>
                ) : (
                    <Badge appearance="tint" color="warning">
                        No connection
                    </Badge>
                )}
                <Tooltip content="Load metadata, generate and write all files for the current .dataverse-gen.json in one step" relationship="description">
                    <Button appearance="primary" icon={<ArrowSyncRegular />} disabled={!canRegenerate || busy} onClick={onRegenerate}>
                        Regenerate
                    </Button>
                </Tooltip>
            </div>
        </header>
    );
}
