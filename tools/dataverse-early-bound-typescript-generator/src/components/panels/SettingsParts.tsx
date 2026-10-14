import { useId, type ReactElement, type ReactNode } from 'react';
import { Badge, Caption1, Card, InfoLabel, Subtitle2, Text, mergeClasses, type BadgeProps } from '@fluentui/react-components';
import type { ProjectDefaults } from '../../config';
import { useSettingsPanelStyles } from '../../styles';

/** A badge on a section header, e.g. where its values are saved. */
export interface SectionBadge {
    label: string;
    color?: BadgeProps['color'];
}

export interface SettingsSectionProps {
    title: string;
    icon: ReactElement;
    badges?: SectionBadge[];
    /** Red accent for settings that delete or can't be undone. */
    danger?: boolean;
    children: ReactNode;
    /** Shown under the rows, e.g. a preview. */
    extra?: ReactNode;
}

/** A card grouping related settings under a heading, with badges saying where the values apply. */
export function SettingsSection({ title, icon, badges = [], danger, children, extra }: SettingsSectionProps) {
    const styles = useSettingsPanelStyles();
    const headingId = useId();
    return (
        <Card className={mergeClasses(styles.section, danger && styles.sectionDanger)} role="group" aria-labelledby={headingId}>
            <div className={styles.sectionHeader}>
                <span className={mergeClasses(styles.sectionIcon, danger && styles.sectionIconDanger)} aria-hidden="true">
                    {icon}
                </span>
                <Subtitle2 id={headingId} className={styles.sectionTitle}>
                    {title}
                </Subtitle2>
                {badges.length > 0 && (
                    <span className={styles.sectionBadges}>
                        {badges.map((b) => (
                            <Badge key={b.label} appearance="tint" size="small" color={b.color ?? 'informative'}>
                                {b.label}
                            </Badge>
                        ))}
                    </span>
                )}
            </div>
            <div>{children}</div>
            {extra && <div className={styles.sectionExtra}>{extra}</div>}
        </Card>
    );
}

export interface SettingRowProps {
    title: string;
    /** One line shown under the title. */
    description: string;
    /** Longer explanation behind the info button. */
    info?: ReactNode;
    /** The value differs from the saved one. */
    changed?: boolean;
    /** `stacked` puts the control under the text, for wide controls such as a text input. */
    layout?: 'inline' | 'stacked';
    /** Renders the control, labelled by the title and described by the description. */
    control: (ids: { labelledBy: string; describedBy: string }) => ReactNode;
}

/** One setting: title and description on the left, its control on the right (or below, when stacked). */
export function SettingRow({ title, description, info, changed, layout = 'inline', control }: SettingRowProps) {
    const styles = useSettingsPanelStyles();
    const titleId = useId();
    const descriptionId = useId();
    return (
        <div className={mergeClasses(styles.row, layout === 'stacked' && styles.rowStacked)}>
            <div className={styles.rowText}>
                <span className={styles.rowTitle}>
                    {info ? (
                        <InfoLabel weight="semibold" info={info} label={{ id: titleId }} infoButton={{ 'aria-label': `About ${title}` }}>
                            {title}
                        </InfoLabel>
                    ) : (
                        <Text id={titleId} weight="semibold">
                            {title}
                        </Text>
                    )}
                    {changed && <span className={styles.changedDot} role="img" aria-label="Changed, not saved yet" title="Changed, not saved yet" />}
                </span>
                <Caption1 id={descriptionId} className={styles.rowDescription}>
                    {description}
                </Caption1>
            </div>
            <div className={styles.rowControl}>{control({ labelledBy: titleId, describedBy: descriptionId })}</div>
        </div>
    );
}

/**
 * What a project with these options generates, as a small folder tree. Every table gets a file in `entities/`; the
 * two interface options add to those files rather than adding files, and `index.ts` is the only optional file.
 */
export function OutputPreview({ defaults }: { defaults: ProjectDefaults }) {
    const styles = useSettingsPanelStyles();
    const root = (defaults.outputRoot.trim() || './src/dataverse-gen').replace(/[\\/]+$/, '');
    const tableContents = ['attributes & metadata', defaults.generateEntityTypes && 'interface', defaults.generateFormContext && 'FormContext']
        .filter(Boolean)
        .join(' + ');
    return (
        <>
            <pre className={styles.preview} aria-label="Preview of the generated folder structure">
                {`${root}/\n`}
                {`├─ entities/      Account.ts  (${tableContents})\n`}
                {`├─ enums/         one file per choice\n`}
                {`├─ actions/  functions/  complextypes/\n`}
                {`├─ metadata.ts\n`}
                {defaults.generateIndex ? (
                    '└─ index.ts       re-exports everything'
                ) : (
                    <span className={styles.previewOff}>└─ index.ts       (off)</span>
                )}
            </pre>
            <Caption1 className={styles.previewNote}>Preview for a project with an account table; updates as you change the options.</Caption1>
        </>
    );
}
