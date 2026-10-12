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
 * Orphans (files in the generated folders that this run would not produce) are reported but never
 * deleted: PPTB's file-system API has no delete, and the user may want to inspect them first.
 */
import { OUTPUT_FOLDERS, type GeneratedFile, type ResolvedConfig } from '../core';
import type { DirectoryEntry, FileSink } from './fileSink';
import { joinPath } from './paths';
import type { FileStatus, PlannedFile, WritePlan, WriteResult } from '../types';

function normalizeNewlines(text: string): string {
    return text.replace(/\r\n?/g, '\n');
}

function splitRelative(relativePath: string): { dir: string; name: string } {
    const index = relativePath.lastIndexOf('/');
    return index === -1 ? { dir: '', name: relativePath } : { dir: relativePath.substring(0, index), name: relativePath.substring(index + 1) };
}

/** Absolute output root for a project (`output.outputRoot` is relative to the project folder). */
export function resolveOutputRoot(projectRoot: string, config: ResolvedConfig): string {
    return joinPath(projectRoot, config.output.outputRoot);
}

export async function createWritePlan(
    sink: FileSink,
    projectRoot: string,
    config: ResolvedConfig,
    generated: GeneratedFile[],
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

        let status: FileStatus = 'new';
        let existingContent: string | null = null;
        if (existing) {
            existingContent = await sink.read(absolutePath);
            status = existingContent !== null && normalizeNewlines(existingContent) === normalizeNewlines(content) ? 'unchanged' : 'changed';
        }
        files.push({
            relativePath,
            absolutePath,
            status,
            content,
            existingContent,
            generatedName: existing && existing.name !== generatedName ? generatedName : undefined,
        });
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

    const counts: Record<FileStatus, number> = { new: 0, changed: 0, unchanged: 0, orphaned: 0 };
    for (const file of files) counts[file.status]++;
    return { projectRoot, outputRoot, files, counts };
}

/** Write the new and changed files of a plan, creating folders as needed. */
export async function applyWritePlan(
    sink: FileSink,
    plan: WritePlan,
    onProgress?: (completed: number, total: number, file: PlannedFile) => void,
): Promise<WriteResult> {
    const toWrite = plan.files.filter((f) => (f.status === 'new' || f.status === 'changed') && f.content !== undefined);
    const directories = new Set<string>();
    for (const file of toWrite) {
        const { dir } = splitRelative(file.relativePath);
        directories.add(dir ? joinPath(plan.outputRoot, dir) : plan.outputRoot);
    }
    for (const dir of directories) await sink.createDirectory(dir);

    let completed = 0;
    for (const file of toWrite) {
        await sink.write(file.absolutePath, file.content as string);
        completed++;
        onProgress?.(completed, toWrite.length, file);
    }
    return { written: toWrite.length, skipped: plan.files.length - toWrite.length };
}
