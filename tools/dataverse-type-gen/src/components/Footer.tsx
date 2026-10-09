import { Link, Text, makeStyles, tokens } from '@fluentui/react-components';

const useStyles = makeStyles({
    footer: {
        padding: `${tokens.spacingVerticalM} ${tokens.spacingHorizontalL}`,
        borderTop: `1px solid ${tokens.colorNeutralStroke2}`,
        color: tokens.colorNeutralForeground3,
    },
});

/** Attribution to the dataverse-gen / dataverse-ify projects this tool is compatible with. */
export function Footer() {
    const styles = useStyles();
    return (
        <footer className={styles.footer}>
            <Text size={200}>
                Output is compatible with Scott Durow's{' '}
                <Link href="https://github.com/scottdurow/dataverse-ify" target="_blank" rel="noreferrer">
                    dataverse-ify
                </Link>{' '}
                runtime and shares its project file with{' '}
                <Link href="https://github.com/scottdurow/dataverse-gen" target="_blank" rel="noreferrer">
                    dataverse-gen
                </Link>{' '}
                (both MIT). Files are generated from the connected environment's metadata; review the preview before
                committing them.
            </Text>
        </footer>
    );
}
