import { Badge, Button, Text, Tooltip, mergeClasses } from '@fluentui/react-components';
import { CodeRegular, PlugConnectedRegular, PlugDisconnectedRegular, SettingsRegular } from '@fluentui/react-icons';
import { version } from '../../../package.json';
import { useHeaderStyles } from '../../styles';

export interface HeaderProps {
    connection: ToolBoxAPI.Connection | null;
    onOpenSettings: () => void;
}

/**
 * The bar across the top: app icon, title, version and subtitle on the left; the active connection and the
 * Settings button on the right.
 */
export function Header({ connection, onOpenSettings }: HeaderProps) {
    const styles = useHeaderStyles();
    return (
        <header className={styles.header}>
            <div className={styles.identity}>
                <span className={styles.appIcon} aria-hidden="true">
                    <CodeRegular />
                </span>
                <div className={styles.titleBlock}>
                    <div className={styles.titleRow}>
                        <Text as="h1" className={styles.title}>
                            Dataverse Early-Bound TypeScript Generator
                        </Text>
                        <Badge appearance="tint" color="brand" size="small">
                            v{version}
                        </Badge>
                    </div>
                    <Text size={200} className={styles.subtitle}>
                        Early-bound TypeScript types and metadata for dataverse-ify, from a .dataverse-gen.json project.
                    </Text>
                </div>
            </div>
            <div className={styles.right}>
                {connection ? (
                    <Tooltip content={connection.url} relationship="description" withArrow>
                        <div className={styles.connection} role="status" aria-label={`Connected to ${connection.name}`}>
                            <span className={mergeClasses(styles.statusDot, styles.statusDotConnected)} aria-hidden="true" />
                            <PlugConnectedRegular className={styles.connectionIcon} aria-hidden="true" />
                            <span className={styles.connectionText}>
                                <span className={styles.connectionLabel}>Connected</span>
                                <span className={styles.connectionName}>{connection.name}</span>
                            </span>
                        </div>
                    </Tooltip>
                ) : (
                    <div className={mergeClasses(styles.connection, styles.connectionDisconnected)} role="status">
                        <span className={mergeClasses(styles.statusDot, styles.statusDotDisconnected)} aria-hidden="true" />
                        <PlugDisconnectedRegular className={styles.connectionIcon} aria-hidden="true" />
                        <span className={styles.connectionText}>
                            <span className={styles.connectionLabel}>Connection</span>
                            <span className={styles.connectionName}>Not connected</span>
                        </span>
                    </div>
                )}
                <Tooltip content="Settings" relationship="label" withArrow>
                    <Button appearance="subtle" size="large" icon={<SettingsRegular />} onClick={onOpenSettings} />
                </Tooltip>
            </div>
        </header>
    );
}
