/**
 * Turns a {@link SchemaModel} into the list of files to write. Synchronous and deterministic, so it can be
 * snapshot-tested (port of `TypescriptGenerator.ts` from dataverse-gen).
 *
 * File order matters: `index.ts` re-exports files in generation order (entities, enums, actions,
 * functions, complex types, metadata), matching the CLI.
 */
import type { ResolvedConfig } from './config';
import { renderComplexType, renderEntity, renderEnum, renderIndex, renderMetadata, renderOperation } from './templates';
import type { GeneratedFile, SchemaModel } from './types';

export const OUTPUT_FOLDERS = {
    entities: 'entities',
    enums: 'enums',
    actions: 'actions',
    functions: 'functions',
    complexTypes: 'complextypes',
} as const;

export function generate(model: SchemaModel, config: ResolvedConfig): GeneratedFile[] {
    const suffix = config.output.fileSuffix;
    const files: GeneratedFile[] = [];
    const add = (folder: string, name: string, content: string) => {
        files.push({ path: `${folder}/${name}${suffix}`, content });
    };

    for (const entity of model.entities) add(OUTPUT_FOLDERS.entities, entity.SchemaName, renderEntity(entity, config));
    for (const enumModel of model.enums) add(OUTPUT_FOLDERS.enums, enumModel.Name, renderEnum(enumModel));
    for (const action of model.actions) add(OUTPUT_FOLDERS.actions, action.Name, renderOperation(action, 'action', config));
    for (const fn of model.functions) add(OUTPUT_FOLDERS.functions, fn.Name, renderOperation(fn, 'function', config));
    for (const complexType of model.complexTypes) add(OUTPUT_FOLDERS.complexTypes, complexType.Name, renderComplexType(complexType));

    files.push({ path: `metadata${suffix}`, content: renderMetadata(model) });
    if (config.generateIndex) {
        files.push({ path: `index${suffix}`, content: renderIndex(files.map((f) => f.path), suffix) });
    }
    return files;
}
