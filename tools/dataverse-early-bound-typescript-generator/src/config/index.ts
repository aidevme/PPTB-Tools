import defaults from './dataverse-early-bound-typescript-generator-config.json';

/** A project created with the New Project dialog. */
export interface ProjectEntry {
    id: string;
    name: string;
    description: string;
    /** Absolute folder path, picked through PPTB's folder picker. */
    location: string;
    /** Project version; new projects start at {@link DEFAULT_PROJECT_VERSION}. */
    version: string;
    /** ISO timestamp. */
    createdOn: string;
    /** ISO timestamp of the last change; equals `createdOn` until the project is changed. */
    modifiedOn: string;
    /**
     * Output files (relative paths) the last Generate produced for this project, used to tell whether the next
     * one adds or drops files. `undefined` until the project is first generated.
     */
    lastGeneratedFiles?: string[];
}

/** Version given to new projects, and to projects saved before versions were recorded. */
export const DEFAULT_PROJECT_VERSION = '1.0.0';

/** Tool settings and projects, saved in PPTB's per-tool settings. */
export interface ToolConfig {
    /** Delete files in the output folders that the current selection no longer generates. */
    deleteOrphanedFiles: boolean;
    projects: ProjectEntry[];
}

/**
 * A saved project, or `undefined` when a required field (id, name, location, createdOn) is missing. Fields
 * added later get defaults, so projects saved by earlier versions of the tool still load.
 */
function normalizeProject(value: unknown): ProjectEntry | undefined {
    const p = value as Partial<Record<keyof ProjectEntry, unknown>> | null;
    if (!p || typeof p !== 'object') return undefined;
    if (typeof p.id !== 'string' || typeof p.name !== 'string' || typeof p.location !== 'string' || typeof p.createdOn !== 'string') return undefined;
    return {
        id: p.id,
        name: p.name,
        description: typeof p.description === 'string' ? p.description : '',
        location: p.location,
        version: typeof p.version === 'string' && p.version ? p.version : DEFAULT_PROJECT_VERSION,
        createdOn: p.createdOn,
        modifiedOn: typeof p.modifiedOn === 'string' && p.modifiedOn ? p.modifiedOn : p.createdOn,
        ...(Array.isArray(p.lastGeneratedFiles) ? { lastGeneratedFiles: p.lastGeneratedFiles.filter((f): f is string => typeof f === 'string') } : {}),
    };
}

function normalizeProjects(values: unknown[]): ProjectEntry[] {
    return values.map(normalizeProject).filter((p): p is ProjectEntry => p !== undefined);
}

/**
 * Default settings from `dataverse-early-bound-typescript-generator-config.json`, bundled at build time.
 * Values the user saves (Settings panel, New Project dialog) are stored in PPTB's per-tool settings and
 * applied on top.
 */
export const toolConfig: ToolConfig = {
    deleteOrphanedFiles: defaults.deleteOrphanedFiles === true,
    projects: normalizeProjects(defaults.projects as unknown[]),
};

/** Applies saved values on top of the defaults, ignoring keys or value types the tool doesn't know. */
export function mergeToolConfig(saved: unknown): ToolConfig {
    const values = (saved && typeof saved === 'object' ? saved : {}) as Partial<Record<keyof ToolConfig, unknown>>;
    return {
        deleteOrphanedFiles: typeof values.deleteOrphanedFiles === 'boolean' ? values.deleteOrphanedFiles : toolConfig.deleteOrphanedFiles,
        projects: Array.isArray(values.projects) ? normalizeProjects(values.projects) : toolConfig.projects,
    };
}

/** Whether two configs hold the same values. */
export function toolConfigEquals(a: ToolConfig, b: ToolConfig): boolean {
    return JSON.stringify(a) === JSON.stringify(b);
}

/** `1.2.3` → `1.2.4`. A version that isn't `major.minor.patch` numbers starts over at `1.0.1`. */
export function bumpPatchVersion(version: string): string {
    const match = /^(\d+)\.(\d+)\.(\d+)$/.exec(version.trim());
    return match ? `${match[1]}.${match[2]}.${Number(match[3]) + 1}` : '1.0.1';
}

/** What a Generate run produced, for {@link recordGeneration}. */
export interface GenerationResult {
    /** Relative paths of every file this run generated (written or already up to date). */
    files: string[];
    /** Relative paths this run created on disk. Used instead of the previous list on a project's first run. */
    newFiles: string[];
}

/**
 * The project after a Generate run. When the run added files, or no longer produces files the previous run
 * did, the version gets a patch bump and `modifiedOn` becomes `now`. The file list is recorded either way.
 * Returns `undefined` when nothing about the project changed.
 */
export function recordGeneration(project: ProjectEntry, result: GenerationResult, now: string): ProjectEntry | undefined {
    const files = [...new Set(result.files)].sort();
    let changed: boolean;
    if (project.lastGeneratedFiles) {
        const previous = new Set(project.lastGeneratedFiles);
        const current = new Set(files);
        changed = files.some((f) => !previous.has(f)) || project.lastGeneratedFiles.some((f) => !current.has(f));
    } else {
        changed = result.newFiles.length > 0;
    }
    if (changed) return { ...project, version: bumpPatchVersion(project.version), modifiedOn: now, lastGeneratedFiles: files };
    const sameList = project.lastGeneratedFiles !== undefined && JSON.stringify(project.lastGeneratedFiles) === JSON.stringify(files);
    return sameList ? undefined : { ...project, lastGeneratedFiles: files };
}
