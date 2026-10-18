import { mergeClasses } from '@fluentui/react-components';
import { CodeRegular } from '@fluentui/react-icons';
import { useAppIconStyles } from '../../styles';

export interface IAppIconProps {
    /** `large` in the Header (44 px), `small` in the Footer (28 px). */
    size: 'large' | 'small';
}

/** The tool's icon: a code glyph on a rounded brand-to-teal tile. Decorative, so hidden from screen readers. */
export function AppIcon({ size }: IAppIconProps) {
    const styles = useAppIconStyles();
    return (
        <span className={mergeClasses(styles.tile, styles[size])} aria-hidden="true">
            <CodeRegular />
        </span>
    );
}
