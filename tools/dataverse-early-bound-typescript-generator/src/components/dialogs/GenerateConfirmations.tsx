import { Text } from '@fluentui/react-components';
import { writeCounts } from '../../services';
import type { WritePlan } from '../../types';

/** How many orphans the confirmation names before summarizing the rest. */
const ORPHANS_LISTED = 10;

/** The Delete orphaned files confirmation's message: what will be deleted, from which folder, and that it can't be undone. */
export function OrphanList({ plan }: { plan: WritePlan }) {
    const orphans = plan.files.filter((f) => f.status === 'orphaned');
    const more = orphans.length - ORPHANS_LISTED;
    return (
        <>
            <Text block>
                {orphans.length === 1 ? 'This file is' : `These ${orphans.length} files are`} in the output folder ({plan.outputRoot}) but no longer
                generated. {orphans.length === 1 ? 'It' : 'They'} will be permanently deleted, not moved to the Recycle Bin or Trash.
            </Text>
            <ul>
                {orphans.slice(0, ORPHANS_LISTED).map((f) => (
                    <li key={f.relativePath}>
                        <code>{f.relativePath}</code>
                    </li>
                ))}
                {more > 0 && <li>…and {more} more</li>}
            </ul>
        </>
    );
}

/** The "Ask before generating" confirmation's message: where files go, what's created and overwritten, and that it can't be undone. */
export function GenerateSummary({ plan, skipDuplicates }: { plan: WritePlan; skipDuplicates: boolean }) {
    const { created, overwritten: changed } = writeCounts(plan, { skipDuplicates });
    const duplicates = plan.counts.duplicate;
    const files = (n: number) => `${n} ${n === 1 ? 'file' : 'files'}`;
    return (
        <>
            <Text block>
                Generate writes to <code>{plan.outputRoot}</code> and saves <code>.dataverse-gen.json</code>.
            </Text>
            <ul>
                {created > 0 && <li>{files(created)} will be created</li>}
                {changed > 0 && <li>{files(changed)} will be overwritten</li>}
            </ul>
            {duplicates > 0 && (
                <Text block>
                    {files(duplicates)} {duplicates === 1 ? 'declares' : 'declare'} duplicate identifiers and{' '}
                    {skipDuplicates ? "won't be written." : "won't compile until the option labels are fixed in Dataverse."}
                </Text>
            )}
            <Text block>Overwritten files can't be restored by the tool; use source control to undo changes.</Text>
        </>
    );
}
