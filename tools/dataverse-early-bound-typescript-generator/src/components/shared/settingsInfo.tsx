/**
 * Titles and explanations for the settings that have a switch both in the Settings panel and in Preview and
 * generate. Both places show the same title and info text, so they live here once.
 */

export const SKIP_DUPLICATES_TITLE = 'Skip duplicated identifier(s)';
export const RENAME_DUPLICATES_TITLE = 'Rename duplicated identifier(s)';
export const DELETE_ORPHANS_TITLE = 'Delete orphaned files';

/** Skip duplicated identifier(s): `skipDuplicateIdentifiers`. */
export const SKIP_DUPLICATES_INFO = (
    <>
        When two choice labels become the same enum member name (for example "Open" and "Open!"), the generated file declares it
        twice and TypeScript won't compile it. Preview marks these files as duplicate identifiers. When on, Generate leaves them
        unwritten, so an existing copy on disk stays as it is; when off, they're written and only reported. Either way, rename one of
        the labels in Dataverse to fix it. The same setting is in Settings → Generate &amp; files and in Preview and generate. Saved as{' '}
        <code>skipDuplicateIdentifiers</code>.
    </>
);

/** Rename duplicated identifier(s): `renameDuplicateIdentifiers`. */
export const RENAME_DUPLICATES_INFO = (
    <>
        When two choice labels become the same enum member name (for example "In Progress" twice), dataverse-gen writes the name
        twice and TypeScript won't compile the file. When on, the first member keeps its name and each later one gets its value
        appended, for example <code>InProgress_700970000</code>, so the file compiles; code that uses the renamed member must use the
        new name. When off, the output matches dataverse-gen and the file is marked as having duplicate identifiers. Renaming the
        label in Dataverse is the lasting fix. Changing this needs a new preview. The same setting is in Settings → Generate &amp;
        files and in Preview and generate. Saved as <code>renameDuplicateIdentifiers</code>.
    </>
);

/** Delete orphaned files: `deleteOrphanedFiles`. */
export const DELETE_ORPHANS_INFO = (
    <>
        Orphaned files are files in the output folders that the current selection no longer generates. When on, Generate deletes them
        permanently after you confirm the list; when off, they're only reported. The same setting is in Settings → Generate &amp; files
        and in Preview and generate. Saved as <code>deleteOrphanedFiles</code>.
    </>
);
