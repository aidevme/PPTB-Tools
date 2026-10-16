/**
 * Compares generated files with the project folder and writes them.
 *
 * Two rules inherited from dataverse-gen:
 * - A file that already exists with a different casing (`entities/account.ts` vs `Account.ts`) is reused
 *   under its existing name, so imports elsewhere in the project keep resolving on case-sensitive
 *   file systems.
 * - Files that are unchanged are not rewritten (line endings are ignored when comparing, so a CRLF
 *   checkout does not churn).
 *
 * Generated files that declare a name more than once (duplicate enum members from colliding option labels) get
 * the `duplicate` status. They're only reported: Generate still writes them when they're new or changed.
 *
 * Orphans (files in the generated folders that this run would not produce) are only reported, unless the
 * user turns on Delete orphaned files: then Generate deletes them after a confirmation. PPTB's file system API
 * has no delete, so that goes through a PPTB terminal (see `PptbFileSink.deleteFiles`).
 */
import { OUTPUT_FOLDERS, type GeneratedFile, type ResolvedConfig } from '../core';
import type { DirectoryEntry, FileSink } from './fileSink';
import { dirname, joinPath } from './paths';
import type { FileStatus, PlannedFile, WritePlan, WriteResult, WriteStatus } from '../types';

function normalizeNewlines(text: string): string {
    return text.replace(/\r\n?/g, '\n');
}

function splitRelative(relativePath: string): { dir: string; name: string } {
    const index = relativePath.lastIndexOf('/');
    return index === -1 ? { dir: '', name: relativePath } : { dir: relativePath.substring(0, index), name: relativePath.substring(index + 1) };
}

/** `1 file`, `2 files`: the count with the singular or plural noun. */
export const plural = (count: number, one: string, many: string) => `${count} ${count === 1 ? one : many}`;

/** What Generate does with a file, including `duplicate` files, which are written like any other. */
export function writeStatusOf(file: PlannedFile): WriteStatus | undefined {
    if (file.status === 'duplicate') return file.writeStatus;
    return file.status === 'orphaned' ? undefined : file.status;
}

/** How Generate treats files: `skipDuplicates` leaves files with duplicate identifiers unwritten. */
export interface WriteOptions {
    skipDuplicates?: boolean;
}

/**
 * Whether Generate writes the file: it's new or changed, whatever its status, unless it has duplicate identifiers
 * and `skipDuplicates` is on.
 */
export function willWrite(file: PlannedFile, options: WriteOptions = {}): boolean {
    if (options.skipDuplicates && file.status === 'duplicate') return false;
    const write = writeStatusOf(file);
    return (write === 'new' || write === 'changed') && file.content !== undefined;
}

/** How many files Generate would create and overwrite, counting `duplicate` files by their write status. */
export function writeCounts(plan: Pick<WritePlan, 'files'>, options: WriteOptions = {}): { created: number; overwritten: number } {
    let created = 0;
    let overwritten = 0;
    for (const file of plan.files) {
        if (!willWrite(file, options)) continue;
        if (writeStatusOf(file) === 'new') created++;
        else overwritten++;
    }
    return { created, overwritten };
}

/** The number of files with each status. */
export function countStatuses(files: PlannedFile[]): Record<FileStatus, number> {
    const counts: Record<FileStatus, number> = { new: 0, changed: 0, unchanged: 0, orphaned: 0, duplicate: 0 };
    for (const file of files) counts[file.status]++;
    return counts;
}

/**
 * One sentence saying what Generate would do with a plan; `deleteOrphans` when Delete orphaned files is on.
 * `writes` defaults to the new and changed counts; pass {@link writeCounts} so `duplicate` files are included.
 * `skipDuplicates` when Skip Duplicated Identifier(s) is on.
 */
export function summarizePlan(
    counts: WritePlan['counts'],
    deleteOrphans = false,
    writes: { created: number; overwritten: number } = { created: counts.new, overwritten: counts.changed },
    skipDuplicates = false,
): string {
    const parts: string[] = [];
    if (writes.created) parts.push(`${plural(writes.created, 'new file', 'new files')} will be created`);
    if (writes.overwritten) parts.push(`${plural(writes.overwritten, 'file', 'files')} will be updated`);
    const written = parts.length ? parts.join(' and ') : 'Everything is up to date; nothing will be written';
    const orphans = counts.orphaned ? `, and ${plural(counts.orphaned, 'orphaned file', 'orphaned files')} will be ${deleteOrphans ? 'deleted' : 'left untouched'}` : '';
    const duplicates = !counts.duplicate
        ? ''
        : skipDuplicates
          ? ` ${plural(counts.duplicate, 'file declares', 'files declare')} duplicate identifiers and won't be written.`
          : ` ${plural(counts.duplicate, 'file declares', 'files declare')} duplicate identifiers and won't compile until the option labels are fixed in Dataverse.`;
    return `${written}${orphans}.${duplicates}`;
}

/**
 * One line saying what a finished Generate run did, e.g. `2 files written · 279 unchanged · 9 orphaned ·
 * .dataverse-gen.json saved`. With `deleted` (the run deleted orphans), orphans read `9 deleted` and any left over
 * `1 orphaned`.
 */
export function summarizeGeneration(written: number, counts: WritePlan['counts'], deleted?: number, skipDuplicates = false): string {
    const orphans = deleted === undefined ? [`${counts.orphaned} orphaned`] : [`${deleted} deleted`, ...(counts.orphaned > deleted ? [`${counts.orphaned - deleted} orphaned`] : [])];
    const duplicates = counts.duplicate ? [`${counts.duplicate} with duplicate identifiers${skipDuplicates ? ' skipped' : ''}`] : [];
    return [`${plural(written, 'file', 'files')} written`, `${counts.unchanged} unchanged`, ...duplicates, ...orphans, '.dataverse-gen.json saved'].join(' · ');
}

/** Absolute output root for a project (`output.outputRoot` is relative to the project folder). */
export function resolveOutputRoot(projectRoot: string, config: ResolvedConfig): string {
    return joinPath(projectRoot, config.output.outputRoot);
}

/**
 * Compares the generated files (paths relative to the output folder) and `projectFiles` (paths relative to the project
 * folder: dataverse-gen's templates) with what's on disk, and finds the orphans in the output folders.
 */
export async function createWritePlan(
    sink: FileSink,
    projectRoot: string,
    config: ResolvedConfig,
    generated: GeneratedFile[],
    projectFiles: GeneratedFile[] = [],
): Promise<WritePlan> {
    const outputRoot = resolveOutputRoot(projectRoot, config);
    const listingCache = new Map<string, Promise<DirectoryEntry[]>>();
    const listDir = (relativeDir: string) => {
        const absolute = relativeDir ? joinPath(outputRoot, relativeDir) : outputRoot;
        let listing = listingCache.get(absolute);
        if (!listing) {
            listing = sink.list(absolute);
            listingCache.set(absolute, listing);
        }
        return listing;
    };

    const files: PlannedFile[] = [];
    const claimed = new Set<string>(); // lower-cased relative paths produced by this run
    // Module specifiers that must be rewritten in the root files (metadata/index) when an existing
    // file with different casing is reused, so the barrel keeps resolving on case-sensitive disks.
    const specifierRenames: Array<{ from: string; to: string }> = [];
    const suffix = config.output.fileSuffix;

    const resolved: Array<{ file: GeneratedFile; relativePath: string; existing?: DirectoryEntry; generatedName: string }> = [];
    for (const file of generated) {
        const { dir, name } = splitRelative(file.path);
        const entries = await listDir(dir);
        const existing = entries.find((e) => e.type === 'file' && e.name.toLowerCase() === name.toLowerCase());
        const onDiskName = existing?.name ?? name;
        const relativePath = dir ? `${dir}/${onDiskName}` : onDiskName;
        claimed.add(relativePath.toLowerCase());
        if (existing && existing.name !== name && dir) {
            specifierRenames.push({ from: `"./${dir}/${name.replace(suffix, '')}"`, to: `"./${dir}/${onDiskName.replace(suffix, '')}"` });
        }
        resolved.push({ file, relativePath, existing, generatedName: name });
    }

    for (const { file, relativePath, existing, generatedName } of resolved) {
        const absolutePath = joinPath(outputRoot, relativePath);
        let content = file.content;
        if (specifierRenames.length > 0 && !relativePath.includes('/')) {
            for (const rename of specifierRenames) content = content.split(rename.from).join(rename.to);
        }

        let writeStatus: WriteStatus = 'new';
        let existingContent: string | null = null;
        if (existing) {
            existingContent = await sink.read(absolutePath);
            writeStatus = existingContent !== null && normalizeNewlines(existingContent) === normalizeNewlines(content) ? 'unchanged' : 'changed';
        }
        const duplicateIdentifiers = file.duplicateIdentifiers?.length ? file.duplicateIdentifiers : undefined;
        files.push({
            relativePath,
            absolutePath,
            status: duplicateIdentifiers ? 'duplicate' : writeStatus,
            content,
            existingContent,
            generatedName: existing && existing.name !== generatedName ? generatedName : undefined,
            ...(duplicateIdentifiers && { writeStatus, duplicateIdentifiers }),
        });
    }

    // Files relative to the project folder (the templates). They're outside the output folders, so they're never orphans.
    for (const file of projectFiles) {
        const absolutePath = joinPath(projectRoot, file.path);
        const existingContent = await sink.read(absolutePath);
        const status: WriteStatus =
            existingContent === null ? 'new' : normalizeNewlines(existingContent) === normalizeNewlines(file.content) ? 'unchanged' : 'changed';
        files.push({ relativePath: file.path, absolutePath, status, content: file.content, existingContent, inProjectFolder: true });
    }

    // Orphans: generated-looking files in the known folders (and the two root files) this run would not write.
    const lowerSuffix = suffix.toLowerCase();
    const rootNames = new Set([`metadata${lowerSuffix}`, `index${lowerSuffix}`]);
    const orphanDirs: Array<{ dir: string; accept: (name: string) => boolean }> = [
        { dir: '', accept: (name) => rootNames.has(name.toLowerCase()) },
        ...Object.values(OUTPUT_FOLDERS).map((dir) => ({ dir, accept: (name: string) => name.toLowerCase().endsWith(lowerSuffix) })),
    ];
    for (const { dir, accept } of orphanDirs) {
        const entries = await listDir(dir);
        for (const entry of entries) {
            if (entry.type !== 'file' || !accept(entry.name)) continue;
            const relativePath = dir ? `${dir}/${entry.name}` : entry.name;
            if (claimed.has(relativePath.toLowerCase())) continue;
            files.push({ relativePath, absolutePath: joinPath(outputRoot, relativePath), status: 'orphaned' });
        }
    }

    return { projectRoot, outputRoot, files, counts: countStatuses(files) };
}

/**
 * Write the new and changed files of a plan (including `duplicate` files that are new or changed, unless
 * `options.skipDuplicates`), creating folders as needed.
 */
export async function applyWritePlan(
    sink: FileSink,
    plan: WritePlan,
    onProgress?: (completed: number, total: number, file: PlannedFile) => void,
    options: WriteOptions = {},
): Promise<WriteResult> {
    const toWrite = plan.files.filter((f) => willWrite(f, options));
    // Each file's own folder: most are in the output folder, the templates in the project folder.
    const directories = new Set<string>();
    for (const file of toWrite) directories.add(dirname(file.absolutePath));
    for (const dir of directories) await sink.createDirectory(dir);

    let completed = 0;
    for (const file of toWrite) {
        await sink.write(file.absolutePath, file.content as string);
        completed++;
        onProgress?.(completed, toWrite.length, file);
    }
    return { written: toWrite.length, skipped: plan.files.length - toWrite.length };
}

export interface DeleteResult {
    /** Relative paths of the orphans that were deleted. */
    deleted: string[];
    /** Relative paths of the orphans that still exist afterwards. */
    failed: string[];
}

/**
 * Deletes a plan's orphaned files. As a guard, only files the plan lists as orphaned, whose absolute path is
 * exactly their relative path inside the output root (no `..` segments), are passed to the sink; nothing else in
 * the project can be deleted.
 */
export async function deleteOrphanedFiles(sink: FileSink, plan: WritePlan): Promise<DeleteResult> {
    const orphans = plan.files.filter(
        (f) => f.status === 'orphaned' && !f.relativePath.split('/').includes('..') && f.absolutePath === joinPath(plan.outputRoot, f.relativePath),
    );
    if (orphans.length === 0) return { deleted: [], failed: [] };
    const remaining = new Set(await sink.deleteFiles(orphans.map((f) => f.absolutePath)));
    return {
        deleted: orphans.filter((f) => !remaining.has(f.absolutePath)).map((f) => f.relativePath),
        failed: orphans.filter((f) => remaining.has(f.absolutePath)).map((f) => f.relativePath),
    };
}
