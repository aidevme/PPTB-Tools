import type { DuplicateIdentifier } from '../core';

/**
 * Outcome of comparing generated files with what is on disk. `duplicate` marks a generated file that declares
 * a name more than once, so it won't compile; it takes the place of new, changed or unchanged, which is kept
 * in {@link PlannedFile.writeStatus}.
 */
export type FileStatus = 'new' | 'changed' | 'unchanged' | 'orphaned' | 'duplicate';

/** What Generate does with a generated file: create it, overwrite it, or leave it alone. */
export type WriteStatus = 'new' | 'changed' | 'unchanged';

export interface PlannedFile {
    /** Path relative to the output root, forward slashes, using the on-disk name when one exists. */
    relativePath: string;
    /** Absolute host path that will be written (or, for orphans, that exists). */
    absolutePath: string;
    status: FileStatus;
    /** New content; `undefined` for orphans. */
    content?: string;
    /** Current on-disk content; `null` for new files, `undefined` when not read (orphans). */
    existingContent?: string | null;
    /** Set when an existing file with different casing is reused for the generated name. */
    generatedName?: string;
    /** For `duplicate` files: whether Generate creates, overwrites or skips the file. Generate still writes it. */
    writeStatus?: WriteStatus;
    /** For `duplicate` files: the names declared more than once. */
    duplicateIdentifiers?: DuplicateIdentifier[];
    /**
     * Set for files outside the output folder: dataverse-gen's templates, written under the config's `templateRoot`.
     * `relativePath` is then relative to the project folder.
     */
    inProjectFolder?: boolean;
}

export interface WritePlan {
    projectRoot: string;
    outputRoot: string;
    files: PlannedFile[];
    counts: Record<FileStatus, number>;
}

export interface WriteResult {
    written: number;
    skipped: number;
}
