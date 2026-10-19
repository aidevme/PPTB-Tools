import { Button, Link, Text, Tooltip } from '@fluentui/react-components';
import { BookOpenRegular, BranchForkRegular, InfoRegular, OpenRegular } from '@fluentui/react-icons';
import { version } from '../../../package.json';
import { useFooterStyles } from '../../styles';
import { AppIcon } from '../shared/AppIcon';
import { CREDITS, DOCUMENTATION_URL, REPOSITORY_URL } from './Footer.const';

/**
 * The bar at the bottom: the tool's name and version; credits to Scott Durow's dataverse-ify and dataverse-gen
 * (both MIT) and a reminder to review generated files; and links to the documentation and the repository.
 * External links open in a new window.
 */
export function Footer() {
    const styles = useFooterStyles();
    return (
        <footer className={styles.footer}>
            <div className={styles.identity}>
                <AppIcon size="small" />
                <span className={styles.identityText}>
                    <span className={styles.toolName}>Early-Bound TypeScript Generator</span>
                    <span className={styles.toolMeta}>v{version} · Part of PPTB Tools</span>
                </span>
            </div>

            <div className={styles.middle}>
                <div className={styles.credits}>
                    <Text size={200}>Compatible with Scott Durow's</Text>
                    {CREDITS.map((credit) => (
                        <Tooltip key={credit.name} content={`${credit.name}: the ${credit.role} (MIT license). Opens in a new window.`} relationship="description" withArrow>
                            <Link href={credit.url} target="_blank" rel="noreferrer" className={styles.creditChip}>
                                {credit.name}
                                <span className={styles.license}>MIT</span>
                            </Link>
                        </Tooltip>
                    ))}
                </div>
                <span className={styles.reminder}>
                    <InfoRegular className={styles.reminderIcon} aria-hidden="true" />
                    Files are generated from the connected environment's metadata; review the preview before committing them.
                </span>
            </div>

            <nav className={styles.links} aria-label="Project links">
                <Button
                    as="a"
                    href={DOCUMENTATION_URL}
                    target="_blank"
                    rel="noreferrer"
                    appearance="subtle"
                    icon={<BookOpenRegular />}
                    iconPosition="before"
                >
                    Documentation <OpenRegular className={styles.externalIcon} aria-label="(opens in a new window)" />
                </Button>
                <Button as="a" href={REPOSITORY_URL} target="_blank" rel="noreferrer" appearance="subtle" icon={<BranchForkRegular />}>
                    GitHub Repo <OpenRegular className={styles.externalIcon} aria-label="(opens in a new window)" />
                </Button>
            </nav>
        </footer>
    );
}
