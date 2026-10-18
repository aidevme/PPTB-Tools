/**
 * Reads and writes the project's `.dataverse-gen.json` through a {@link FileSink}.
 */
import { CONFIG_FILE_NAME, createDefaultConfig, parseConfig, serializeConfig, type DataverseGenConfig } from '../core';
import type { FileSink } from './fileSink';
import { joinPath } from './paths';

/** The project's `.dataverse-gen.json`, as {@link loadProjectConfig} found it. */
export interface ProjectConfigState {
    /** Absolute path of the config file (whether or not it exists yet). */
    path: string;
    /** Whether the file exists; a new project's config is only written on the first Generate. */
    exists: boolean;
    /** The parsed config, or the defaults a fresh `dataverse-gen init` would write when the file doesn't exist. */
    config: DataverseGenConfig;
}

/** Returns the absolute path of the project's `.dataverse-gen.json`. */
export function configPathFor(projectRoot: string): string {
    return joinPath(projectRoot, CONFIG_FILE_NAME);
}

/** Load the config if present, otherwise the defaults a fresh `dataverse-gen init` would write. */
export async function loadProjectConfig(sink: FileSink, projectRoot: string): Promise<ProjectConfigState> {
    const path = configPathFor(projectRoot);
    const text = await sink.read(path);
    if (text === null) return { path, exists: false, config: createDefaultConfig() };
    return { path, exists: true, config: parseConfig(text) };
}

/**
 * Writes the config to the project's `.dataverse-gen.json`, replacing the file.
 * @returns The absolute path written.
 */
export async function saveProjectConfig(sink: FileSink, projectRoot: string, config: DataverseGenConfig): Promise<string> {
    const path = configPathFor(projectRoot);
    await sink.write(path, serializeConfig(config));
    return path;
}
