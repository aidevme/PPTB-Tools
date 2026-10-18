import { Text } from '@fluentui/react-components';
import { DeleteRegular, SaveRegular } from '@fluentui/react-icons';
import { pendingWriteCount, plural, writeCounts } from '../../services';
import type { WritePlan } from '../../types';
import { ConfirmationDialog } from './ConfirmationDialog';

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
    const files = (n: number) => plural(n, 'file', 'files');
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

/** Props for {@link GenerateConfirmationDialogs}. */
export interface IGenerateConfirmationDialogsProps {
    /** The write plan the confirmations describe; neither dialog opens while it's `null`. */
    plan: WritePlan | null;
    /** Whether files with duplicate identifiers are left unwritten; changes the counts and the duplicate warning. */
    skipDuplicates: boolean;
    /** The Delete orphaned files confirmation is open. */
    deleteOpen: boolean;
    /** Called when the Delete orphaned files confirmation is accepted (its button also names pending writes). */
    onConfirmDelete: () => void;
    /** Called when the Delete orphaned files confirmation is cancelled or dismissed with Escape. */
    onCancelDelete: () => void;
    /** The "Ask before generating" confirmation is open. */
    generateOpen: boolean;
    /** Called when the "Ask before generating" confirmation is accepted. */
    onConfirmGenerate: () => void;
    /** Called when the "Ask before generating" confirmation is cancelled or dismissed with Escape. */
    onCancelGenerate: () => void;
}

/** Generate's two confirmations: deleting orphaned files (which also covers the writes), and "Ask before generating". */
export function GenerateConfirmationDialogs({
    plan,
    skipDuplicates,
    deleteOpen,
    onConfirmDelete,
    onCancelDelete,
    generateOpen,
    onConfirmGenerate,
    onCancelGenerate,
}: IGenerateConfirmationDialogsProps) {
    const pending = plan ? pendingWriteCount(plan, { skipDuplicates }) : 0;
    const orphaned = plan?.counts.orphaned ?? 0;
    return (
        <>
            <ConfirmationDialog
                open={deleteOpen && !!plan}
                title="Delete orphaned files?"
                message={plan && <OrphanList plan={plan} />}
                confirmLabel={pending > 0 ? `Generate and delete ${orphaned}` : `Delete ${plural(orphaned, 'file', 'files')}`}
                confirmIcon={<DeleteRegular />}
                onConfirm={onConfirmDelete}
                onCancel={onCancelDelete}
            />
            <ConfirmationDialog
                open={generateOpen && !!plan}
                title="Generate files?"
                message={plan && <GenerateSummary plan={plan} skipDuplicates={skipDuplicates} />}
                confirmLabel={`Generate ${plural(pending, 'file', 'files')}`}
                confirmIcon={<SaveRegular />}
                onConfirm={onConfirmGenerate}
                onCancel={onCancelGenerate}
            />
        </>
    );
}
