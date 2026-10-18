import { Tooltip, mergeClasses } from '@fluentui/react-components';
import { PlugConnectedRegular, PlugDisconnectedRegular } from '@fluentui/react-icons';
import { useConnectionStatusStyles } from '../../styles';

export interface IConnectionStatusProps {
    /** The active PPTB connection, or `null` when none is selected. */
    connection: ToolBoxAPI.Connection | null;
}

/**
 * The Header's connection pill: a green dot and the environment name (with its URL in a tooltip) when connected,
 * or a yellow "Not connected" pill. It's a `status` region, so changes are announced; the connected pill is
 * focusable, so the tooltip also opens from the keyboard.
 */
export function ConnectionStatus({ connection }: IConnectionStatusProps) {
    const styles = useConnectionStatusStyles();
    if (!connection) {
        return (
            <div className={mergeClasses(styles.pill, styles.pillDisconnected)} role="status">
                <span className={mergeClasses(styles.dot, styles.dotDisconnected)} aria-hidden="true" />
                <PlugDisconnectedRegular className={styles.icon} aria-hidden="true" />
                <span className={styles.text}>
                    <span className={styles.label}>Connection</span>
                    <span className={styles.name}>Not connected</span>
                </span>
            </div>
        );
    }
    return (
        <Tooltip content={connection.url} relationship="description" withArrow>
            {/* Focusable so keyboard users can open the URL tooltip. */}
            <div className={styles.pill} role="status" aria-label={`Connected to ${connection.name}`} tabIndex={0}>
                <span className={mergeClasses(styles.dot, styles.dotConnected)} aria-hidden="true" />
                <PlugConnectedRegular className={styles.icon} aria-hidden="true" />
                <span className={styles.text}>
                    <span className={styles.label}>Connected</span>
                    <span className={styles.name}>{connection.name}</span>
                </span>
            </div>
        </Tooltip>
    );
}
