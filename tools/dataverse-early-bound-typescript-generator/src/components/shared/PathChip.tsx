import { Button, Tooltip } from '@fluentui/react-components';
import { CopyRegular } from '@fluentui/react-icons';
import { usePathChipStyles } from '../../styles';
import { shortenPath } from './format';

export interface IPathChipProps {
    path: string;
    /** What the path is, for example "Project folder path": the copy notification's label and, lowercased, the copy button's tooltip. */
    label: string;
    onCopy: (path: string, label: string) => void;
    /** Longest text shown before the middle of the path is shortened; defaults to `shortenPath`'s 48. */
    maxLength?: number;
    /** `plain` is monospace text that truncates; `filled` adds a neutral background. Defaults to `plain`. */
    appearance?: 'plain' | 'filled';
}

/**
 * A path shortened in the middle, with the full path in a tooltip, and a copy button. Renders a fragment, so the
 * parent row decides the layout.
 */
export function PathChip({ path, label, onCopy, maxLength, appearance = 'plain' }: IPathChipProps) {
    const styles = usePathChipStyles();
    return (
        <>
            <Tooltip content={path} relationship="description" withArrow>
                <span className={styles[appearance]}>{shortenPath(path, maxLength)}</span>
            </Tooltip>
            <Tooltip content={`Copy ${label.charAt(0).toLowerCase()}${label.slice(1)}`} relationship="label" withArrow>
                <Button appearance="subtle" size="small" icon={<CopyRegular />} onClick={() => onCopy(path, label)} />
            </Tooltip>
        </>
    );
}
