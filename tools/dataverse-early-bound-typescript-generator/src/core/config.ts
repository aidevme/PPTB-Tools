/**
 * `.dataverse-gen.json` — the project configuration file shared with Scott Durow's `dataverse-gen` CLI.
 *
 * The shape and defaults mirror `MetadataGeneratorConfig.ts` in dataverse-gen so a project can be
 * generated from either tool interchangeably. Unknown keys are preserved on round-trip.
 */

export interface OutputConfig {
    /** Folder the generated files go to, relative to the project root. */
    outputRoot?: string;
    /** Ejected EJS templates folder — honoured by the CLI only; this tool uses built-in templates. */
    templateRoot?: string;
    /** File extension for generated files (default `.ts`). */
    fileSuffix?: string;
    /** CLI-only: cache the EDMX document on disk. */
    useCache?: boolean;
}

export interface ImportType {
    name?: string;
    import?: string;
}

export interface DataverseGenConfig {
    entities?: string[];
    actions?: string[];
    functions?: string[];
    output?: OutputConfig;
    generateIndex?: boolean;
    generateFormContext?: boolean;
    generateEntityTypes?: boolean;
    referencedTypes?: Record<string, ImportType>;
    /** Any other keys found in the file are kept as-is. */
    [key: string]: unknown;
}

/** Fully-resolved configuration (every option the generator reads has a value). */
export interface ResolvedConfig {
    entities: string[];
    actions: string[];
    functions: string[];
    output: Required<Pick<OutputConfig, 'outputRoot' | 'fileSuffix'>> & OutputConfig;
    generateIndex: boolean;
    generateFormContext: boolean;
    generateEntityTypes: boolean;
    referencedTypes: Record<string, ImportType>;
}

export const CONFIG_FILE_NAME = '.dataverse-gen.json';

/** Same defaults as dataverse-gen's `defaultOptions`. */
export const DEFAULT_REFERENCED_TYPES: Record<string, ImportType> = {
    Object: { name: 'ObjectValue' },
    Guid: { name: 'Guid', import: 'dataverse-ify' },
    Entity: { name: 'IEntity', import: 'dataverse-ify' },
    EntityReference: { name: 'EntityReference', import: 'dataverse-ify' },
    WebApiExecuteRequest: { name: 'WebApiExecuteRequest', import: 'dataverse-ify' },
    StructuralProperty: { name: 'StructuralProperty', import: 'dataverse-ify' },
    OperationType: { name: 'OperationType', import: 'dataverse-ify' },
    ActivityParty: { name: 'ActivityParty', import: 'dataverse-ify' },
    enums: { import: '../enums/' },
    complexTypes: { import: '../complextypes/' },
    entityTypes: { import: '../entities/' },
};

export const DEFAULT_OUTPUT_ROOT = './src/dataverse-gen';

/** Config written for a brand new project (same as dataverse-gen's `.dataverse-gen.template.json`). */
export function createDefaultConfig(): DataverseGenConfig {
    return {
        entities: [],
        actions: [],
        functions: [],
        generateIndex: true,
        generateFormContext: false,
        generateEntityTypes: true,
        output: {
            outputRoot: DEFAULT_OUTPUT_ROOT,
        },
    };
}

/**
 * Deep-merge user config over the defaults, the way dataverse-gen's `_merge(defaultOptions, options)`
 * does. `referencedTypes` entries are merged per key so a partial override keeps the other defaults.
 */
export function resolveConfig(config: DataverseGenConfig | undefined): ResolvedConfig {
    const c = config ?? {};
    const referencedTypes: Record<string, ImportType> = {};
    for (const key of new Set([...Object.keys(DEFAULT_REFERENCED_TYPES), ...Object.keys(c.referencedTypes ?? {})])) {
        referencedTypes[key] = { ...DEFAULT_REFERENCED_TYPES[key], ...(c.referencedTypes?.[key] ?? {}) };
    }
    return {
        entities: [...(c.entities ?? [])],
        actions: [...(c.actions ?? [])],
        functions: [...(c.functions ?? [])],
        output: {
            useCache: false,
            templateRoot: './_templates',
            ...(c.output ?? {}),
            outputRoot: c.output?.outputRoot || DEFAULT_OUTPUT_ROOT,
            fileSuffix: c.output?.fileSuffix || '.ts',
        },
        generateIndex: c.generateIndex ?? true,
        generateFormContext: c.generateFormContext ?? false,
        generateEntityTypes: c.generateEntityTypes ?? true,
        referencedTypes,
    };
}

/** Parse the JSON text of a `.dataverse-gen.json` file, tolerating a UTF-8 BOM. */
export function parseConfig(json: string): DataverseGenConfig {
    const text = json.replace(/^﻿/, '');
    const parsed: unknown = JSON.parse(text);
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
        throw new Error(`${CONFIG_FILE_NAME} must contain a JSON object`);
    }
    const config = parsed as DataverseGenConfig;
    for (const key of ['entities', 'actions', 'functions'] as const) {
        const value = config[key];
        if (value !== undefined && !Array.isArray(value)) {
            throw new Error(`${CONFIG_FILE_NAME}: "${key}" must be an array of names`);
        }
    }
    return config;
}

/** Serialise the way dataverse-gen does (`JSON.stringify(config, null, 2)`), with a trailing newline. */
export function serializeConfig(config: DataverseGenConfig): string {
    return JSON.stringify(config, null, 2) + '\n';
}

/**
 * Key of this tool's own settings object in `.dataverse-gen.json`. The dataverse-gen CLI keeps it (it writes the whole
 * file back) and ignores it; namespacing it means it can't collide with a future dataverse-gen option.
 */
export const TOOL_CONFIG_KEY = 'pptbEarlyBoundGenerator';

/** This tool's per-project settings, stored under {@link TOOL_CONFIG_KEY} in `.dataverse-gen.json`. */
export interface ProjectToolSettings {
    /** Use the custom enum template for this project (spec 001): rename duplicates and write the custom `enum.ejs`. */
    customEnumTemplate?: boolean;
    /** The kinds of generated file chosen in Custom Templates on the Preview card (not used for generating yet). */
    customTemplates?: Partial<Record<CustomTemplateKind, boolean>>;
    /** Keys a later version of the tool may add are kept as-is. */
    [key: string]: unknown;
}

/** The project's tool settings object, or `{}` when it's missing or not an object. */
function toolSettingsOf(config: DataverseGenConfig): ProjectToolSettings {
    const value = config[TOOL_CONFIG_KEY];
    return value !== null && typeof value === 'object' && !Array.isArray(value) ? (value as ProjectToolSettings) : {};
}

/**
 * The project's custom enum template choice.
 *
 * @param config - The project's `.dataverse-gen.json` content.
 * @returns `true` or `false` when the file sets it, or `undefined` when it doesn't (or the value isn't a boolean), so
 * the default applies.
 */
export function projectCustomEnumTemplate(config: DataverseGenConfig): boolean | undefined {
    const value = toolSettingsOf(config).customEnumTemplate;
    return typeof value === 'boolean' ? value : undefined;
}

/**
 * A copy of the config with the project's custom enum template choice set; every other key, including other keys of
 * the tool's settings object, is kept.
 *
 * @param config - The project's `.dataverse-gen.json` content.
 * @param value - The choice to store.
 * @returns The updated config; `config` itself isn't changed.
 */
export function withProjectCustomEnumTemplate(config: DataverseGenConfig, value: boolean): DataverseGenConfig {
    return { ...config, [TOOL_CONFIG_KEY]: { ...toolSettingsOf(config), customEnumTemplate: value } };
}

/** The kinds of generated file a project can choose custom templates for, in the order Custom Templates lists them. */
export const CUSTOM_TEMPLATE_KINDS = ['actions', 'complexTypes', 'entities', 'enums', 'functions', 'metadata'] as const;

/** One of {@link CUSTOM_TEMPLATE_KINDS}. */
export type CustomTemplateKind = (typeof CUSTOM_TEMPLATE_KINDS)[number];

/** Which kinds of generated file a project chose custom templates for. */
export type CustomTemplateSelection = Record<CustomTemplateKind, boolean>;

/**
 * The project's Custom Templates choices.
 *
 * @remarks Only stored for now: nothing reads them when generating.
 *
 * @param config - The project's `.dataverse-gen.json` content.
 * @returns Every kind, `true` only where the file sets it to `true`; a missing or non-boolean value is `false`.
 */
export function projectCustomTemplates(config: DataverseGenConfig): CustomTemplateSelection {
    const stored = toolSettingsOf(config).customTemplates;
    const values = stored !== null && typeof stored === 'object' && !Array.isArray(stored) ? (stored as Record<string, unknown>) : {};
    return Object.fromEntries(CUSTOM_TEMPLATE_KINDS.map((kind) => [kind, values[kind] === true])) as CustomTemplateSelection;
}

/**
 * A copy of the config with the project's Custom Templates choices set; every other key, including other keys of the
 * tool's settings object, is kept.
 *
 * @param config - The project's `.dataverse-gen.json` content.
 * @param selection - The choices to store, one per kind.
 * @returns The updated config; `config` itself isn't changed.
 */
export function withProjectCustomTemplates(config: DataverseGenConfig, selection: CustomTemplateSelection): DataverseGenConfig {
    const customTemplates = Object.fromEntries(CUSTOM_TEMPLATE_KINDS.map((kind) => [kind, selection[kind] === true]));
    return { ...config, [TOOL_CONFIG_KEY]: { ...toolSettingsOf(config), customTemplates } };
}
