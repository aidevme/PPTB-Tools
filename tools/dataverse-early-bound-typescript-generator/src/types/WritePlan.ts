/** Outcome of comparing generated files with what is on disk. */
export type FileStatus = 'new' | 'changed' | 'unchanged' | 'orphaned';

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
