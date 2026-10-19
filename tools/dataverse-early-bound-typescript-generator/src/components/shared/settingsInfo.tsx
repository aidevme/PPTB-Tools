/**
 * Titles and explanations for the settings that have a switch both in the Settings panel and in Preview and
 * generate. Both places show the same title and info text, so they live here once.
 */

/** Switch label for `skipDuplicateIdentifiers`, explained by {@link SKIP_DUPLICATES_INFO}. */
export const SKIP_DUPLICATES_TITLE = 'Skip duplicated identifier(s)';
/** Switch label for `renameDuplicateIdentifiers`, explained by {@link RENAME_DUPLICATES_INFO}. */
export const RENAME_DUPLICATES_TITLE = 'Rename duplicated identifier(s)';
/** Switch label for `deleteOrphanedFiles`, explained by {@link DELETE_ORPHANS_INFO}. */
export const DELETE_ORPHANS_TITLE = 'Delete orphaned files';
/** Switch label for the project's custom enum template, explained by {@link CUSTOM_ENUM_TEMPLATE_INFO}. */
export const CUSTOM_ENUM_TEMPLATE_TITLE = 'Custom enum template';

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

/**
 * Custom enum template: the project's `pptbEarlyBoundGenerator.customEnumTemplate`. Also the core of the proposal Preview
 * and generate shows when a preview finds duplicate identifiers.
 */
export const CUSTOM_ENUM_TEMPLATE_INFO = (
    <>
        Fixes duplicate identifiers in the generated files and for the dataverse-gen CLI alike. When on, each later member whose name is
        taken gets its value appended, for example <code>InProgress_700970000</code>, as Rename duplicated identifier(s) does, and
        Generate writes a custom <code>enum.ejs</code> to the project's <code>templateRoot</code> in place of dataverse-gen's,
        replacing an edited copy, so the CLI renames them the same way. The CLI only gets it while Generate templates is on. When off,
        the output and <code>enum.ejs</code> are dataverse-gen's again. Renaming the labels in Dataverse is the lasting fix, and a
        reorder of the options can move the suffix to another member. Changing this needs a new preview. It's set per project, on
        the Options card and in Preview and generate; Settings → Options sets the default for projects that don't have a value yet.
        Saved in the project's <code>.dataverse-gen.json</code> as <code>pptbEarlyBoundGenerator.customEnumTemplate</code>, which
        the dataverse-gen CLI ignores.
    </>
);

/** Title of the confirmation shown before the custom enum template replaces an edited `enum.ejs` (spec 001, FR-012). */
export const EDITED_ENUM_TEMPLATE_TITLE = 'Replace your edited enum.ejs?';

/** Confirm button of that confirmation; the same words as the proposal's button. */
export const EDITED_ENUM_TEMPLATE_CONFIRM = 'Use custom enum template';

/**
 * Message of the confirmation shown before the custom enum template replaces an edited `enum.ejs`.
 *
 * @param path - The project's `enum.ejs`, as an absolute path.
 * @returns The dialog's message: which file, why it looks edited, what the next Generate does, and that nothing is
 * written now.
 */
export function editedEnumTemplateMessage(path: string) {
    return (
        <>
            <code>{path}</code> differs from dataverse-gen's <code>enum.ejs</code>, so it looks edited. With the custom enum template
            on, the next Generate replaces it with the custom template, and your edits are lost unless they're in source control.
            Nothing is written now: the next preview lists the change first.
        </>
    );
}

/** Delete orphaned files: `deleteOrphanedFiles`. */
export const DELETE_ORPHANS_INFO = (
    <>
        Orphaned files are files in the output folders that the current selection no longer generates. When on, Generate deletes them
        permanently after you confirm the list; when off, they're only reported. The same setting is in Settings → Generate &amp; files
        and in Preview and generate. Saved as <code>deleteOrphanedFiles</code>.
    </>
);
