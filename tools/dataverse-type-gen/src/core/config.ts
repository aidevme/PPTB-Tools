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
