import defaults from './dataverse-early-bound-typescript-generator-config.json';
import { projectCustomEnumTemplate, withProjectCustomEnumTemplate, type DataverseGenConfig } from '../core';

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

/**
 * Options a new project starts with: applied when a project folder without `.dataverse-gen.json` is opened.
 * Projects that already have the file keep their own values. Same meaning as the matching
 * `.dataverse-gen.json` keys.
 */
export interface ProjectDefaults {
    /** `output.outputRoot`: output folder, relative to the project folder. */
    outputRoot: string;
    generateEntityTypes: boolean;
    generateFormContext: boolean;
    generateIndex: boolean;
    /**
     * Default for the project's custom enum template (`pptbEarlyBoundGenerator.customEnumTemplate`): unlike the other
     * options, it only fills in a project whose `.dataverse-gen.json` has no value, and never replaces one.
     */
    customEnumTemplate: boolean;
}

/** Settings on the General tab: how the tool itself behaves. */
export interface GeneralSettings {
    /** Show the "Project loaded" notification after a project opens. */
    showProjectLoadedNotification: boolean;
    /** Show the "Preview ready" notification after a preview. */
    showPreviewReadyNotification: boolean;
    /** Show the "Generation complete" notification after Generate. */
    showGenerationCompleteNotification: boolean;
    /** Recent projects offered on the Project card; 0 hides the list. See {@link RECENT_PROJECT_COUNT_RANGE}. */
    recentProjectCount: number;
    /** Rows shown at most in each Select table. See {@link SELECTION_ROW_LIMIT_RANGE}. */
    selectionRowLimit: number;
}

/** Allowed range for {@link GeneralSettings.recentProjectCount}. */
export const RECENT_PROJECT_COUNT_RANGE = { min: 0, max: 10 } as const;
/** Allowed range for {@link GeneralSettings.selectionRowLimit}. */
export const SELECTION_ROW_LIMIT_RANGE = { min: 100, max: 2000 } as const;

/** Tool settings and projects, saved in PPTB's per-tool settings. */
export interface ToolConfig {
    general: GeneralSettings;
    /** Delete files in the output folders that the current selection no longer generates. */
    deleteOrphanedFiles: boolean;
    /** Ask for confirmation before Generate writes new and changed files. */
    confirmBeforeGenerate: boolean;
    /** Don't write generated files that declare a name more than once (duplicate enum members). */
    skipDuplicateIdentifiers: boolean;
    /** Rename later duplicate enum members to `<Name>_<Value>` so the generated files compile. */
    renameDuplicateIdentifiers: boolean;
    /** Write dataverse-gen's EJS templates to the project's `templateRoot` on Generate, like `dataverse-gen eject`. */
    generateTemplates: boolean;
    /**
     * Use the custom enum template: rename later duplicate enum members in the output (as `renameDuplicateIdentifiers`
     * does) and, when `generateTemplates` is on, write the custom `enum.ejs` that does the same for the dataverse-gen CLI.
     */
    customEnumTemplate: boolean;
    projectDefaults: ProjectDefaults;
    projects: ProjectEntry[];
}

/** The tool's own General defaults, used when the bundled JSON doesn't set a value. */
const BUILT_IN_GENERAL_SETTINGS: GeneralSettings = {
    showProjectLoadedNotification: true,
    showPreviewReadyNotification: true,
    showGenerationCompleteNotification: true,
    recentProjectCount: 3,
    selectionRowLimit: 500,
};

/** A whole number within `range`, or `fallback` when `value` isn't a finite number. */
function clampInteger(value: unknown, range: { min: number; max: number }, fallback: number): number {
    if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
    return Math.min(range.max, Math.max(range.min, Math.round(value)));
}

/** Each value from `value` when it has the right type (numbers clamped to their range), else from `fallback`. */
function normalizeGeneralSettings(value: unknown, fallback: GeneralSettings): GeneralSettings {
    const v = (value && typeof value === 'object' ? value : {}) as Partial<Record<keyof GeneralSettings, unknown>>;
    const flag = (key: 'showProjectLoadedNotification' | 'showPreviewReadyNotification' | 'showGenerationCompleteNotification') =>
        typeof v[key] === 'boolean' ? (v[key] as boolean) : fallback[key];
    return {
        showProjectLoadedNotification: flag('showProjectLoadedNotification'),
        showPreviewReadyNotification: flag('showPreviewReadyNotification'),
        showGenerationCompleteNotification: flag('showGenerationCompleteNotification'),
        recentProjectCount: clampInteger(v.recentProjectCount, RECENT_PROJECT_COUNT_RANGE, fallback.recentProjectCount),
        selectionRowLimit: clampInteger(v.selectionRowLimit, SELECTION_ROW_LIMIT_RANGE, fallback.selectionRowLimit),
    };
}

/** dataverse-gen's own defaults, used when the bundled JSON doesn't set a value. */
const BUILT_IN_PROJECT_DEFAULTS: ProjectDefaults = {
    outputRoot: './src/dataverse-gen',
    generateEntityTypes: true,
    generateFormContext: false,
    generateIndex: true,
    customEnumTemplate: false,
};

/** Each value from `value` when it has the right type (and, for `outputRoot`, isn't blank), else from `fallback`. */
function normalizeProjectDefaults(value: unknown, fallback: ProjectDefaults): ProjectDefaults {
    const v = (value && typeof value === 'object' ? value : {}) as Partial<Record<keyof ProjectDefaults, unknown>>;
    const flag = (key: 'generateEntityTypes' | 'generateFormContext' | 'generateIndex' | 'customEnumTemplate') =>
        typeof v[key] === 'boolean' ? (v[key] as boolean) : fallback[key];
    return {
        outputRoot: typeof v.outputRoot === 'string' && v.outputRoot.trim() ? v.outputRoot.trim() : fallback.outputRoot,
        generateEntityTypes: flag('generateEntityTypes'),
        generateFormContext: flag('generateFormContext'),
        generateIndex: flag('generateIndex'),
        customEnumTemplate: flag('customEnumTemplate'),
    };
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
    general: normalizeGeneralSettings(defaults.general, BUILT_IN_GENERAL_SETTINGS),
    deleteOrphanedFiles: defaults.deleteOrphanedFiles === true,
    confirmBeforeGenerate: defaults.confirmBeforeGenerate === true,
    skipDuplicateIdentifiers: defaults.skipDuplicateIdentifiers === true,
    renameDuplicateIdentifiers: defaults.renameDuplicateIdentifiers === true,
    // On unless the bundled JSON turns it off, so Generate keeps writing the templates by default.
    generateTemplates: defaults.generateTemplates !== false,
    customEnumTemplate: defaults.customEnumTemplate === true,
    projectDefaults: normalizeProjectDefaults(defaults.projectDefaults, BUILT_IN_PROJECT_DEFAULTS),
    projects: normalizeProjects(defaults.projects as unknown[]),
};

/** Applies saved values on top of the defaults, ignoring keys or value types the tool doesn't know. */
export function mergeToolConfig(saved: unknown): ToolConfig {
    const values = (saved && typeof saved === 'object' ? saved : {}) as Partial<Record<keyof ToolConfig, unknown>>;
    return {
        general: normalizeGeneralSettings(values.general, toolConfig.general),
        deleteOrphanedFiles: typeof values.deleteOrphanedFiles === 'boolean' ? values.deleteOrphanedFiles : toolConfig.deleteOrphanedFiles,
        confirmBeforeGenerate:
            typeof values.confirmBeforeGenerate === 'boolean' ? values.confirmBeforeGenerate : toolConfig.confirmBeforeGenerate,
        skipDuplicateIdentifiers:
            typeof values.skipDuplicateIdentifiers === 'boolean' ? values.skipDuplicateIdentifiers : toolConfig.skipDuplicateIdentifiers,
        renameDuplicateIdentifiers:
            typeof values.renameDuplicateIdentifiers === 'boolean' ? values.renameDuplicateIdentifiers : toolConfig.renameDuplicateIdentifiers,
        generateTemplates: typeof values.generateTemplates === 'boolean' ? values.generateTemplates : toolConfig.generateTemplates,
        customEnumTemplate: typeof values.customEnumTemplate === 'boolean' ? values.customEnumTemplate : toolConfig.customEnumTemplate,
        projectDefaults: normalizeProjectDefaults(values.projectDefaults, toolConfig.projectDefaults),
        projects: Array.isArray(values.projects) ? normalizeProjects(values.projects) : toolConfig.projects,
    };
}

/**
 * A new project's `.dataverse-gen.json` with the project defaults applied. Everything else in `config`
 * (selection, other output options) is kept.
 *
 * @remarks The custom enum template is the exception: its default is only filled in when the project has no value,
 * so a project keeps its own choice when it's opened again or the default changes (spec 001, Amendment 2).
 *
 * @param config - The project's `.dataverse-gen.json` content.
 * @param projectDefaults - The Settings panel's Options.
 * @returns The config with the defaults applied.
 */
export function applyProjectDefaults(config: DataverseGenConfig, projectDefaults: ProjectDefaults): DataverseGenConfig {
    const applied: DataverseGenConfig = {
        ...config,
        generateEntityTypes: projectDefaults.generateEntityTypes,
        generateFormContext: projectDefaults.generateFormContext,
        generateIndex: projectDefaults.generateIndex,
        output: { ...(config.output ?? {}), outputRoot: projectDefaults.outputRoot },
    };
    return projectCustomEnumTemplate(config) === undefined
        ? withProjectCustomEnumTemplate(applied, projectDefaults.customEnumTemplate)
        : applied;
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
