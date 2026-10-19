/**
 * Turns a {@link SchemaModel} into the list of files to write. Synchronous and deterministic, so it can be
 * snapshot-tested (port of `TypescriptGenerator.ts` from dataverse-gen).
 *
 * File order matters: `index.ts` re-exports files in generation order (entities, enums, actions,
 * functions, complex types, metadata), matching the CLI.
 */
import type { ResolvedConfig } from './config';
import { renderComplexType, renderEntity, renderEnum, renderIndex, renderMetadata, renderOperation } from './templates';
import type { DuplicateIdentifier, EnumModel, GeneratedFile, SchemaModel } from './types';

export const OUTPUT_FOLDERS = {
    entities: 'entities',
    enums: 'enums',
    actions: 'actions',
    functions: 'functions',
    complexTypes: 'complextypes',
} as const;

/**
 * Enum members that share a name. Option labels become member names after `makeCodeSafe`, so two labels
 * such as "Open" and "Open!" collide, and TypeScript rejects the file. The output is kept as dataverse-gen
 * writes it; the collision is only reported, so the labels can be fixed in Dataverse.
 */
export function findDuplicateEnumMembers(enumModel: EnumModel): DuplicateIdentifier[] {
    const byName = new Map<string, string[]>();
    for (const member of enumModel.Members) {
        const values = byName.get(member.Name);
        if (values) values.push(member.Value);
        else byName.set(member.Name, [member.Value]);
    }
    return [...byName].filter(([, values]) => values.length > 1).map(([name, values]) => ({ name, values }));
}

/**
 * The enum with every later duplicate member renamed to `<Name>_<Value>` (for example `InProgress_700970000`), so the
 * file compiles. The first member with a name keeps it. A renamed name that's itself taken gets the value appended
 * again until it's free. Members are kept in order with their values.
 *
 * @remarks Only choice (option set) enums can have duplicates: their member names come from labels made code-safe.
 * `StringMembers` enums come from the `$metadata` enum types, whose member names are unique, so they're returned with
 * the same names. (A renamed string member would also change its value, since the value is the member name.) The
 * custom `enum.ejs` (`CUSTOM_ENUM_TEMPLATE`) applies the same rule for the dataverse-gen CLI.
 *
 * @param enumModel - The enum as built from the metadata.
 * @returns A copy with unique member names; members that didn't need renaming are the same objects.
 */
export function renameDuplicateEnumMembers(enumModel: EnumModel): EnumModel {
    const used = new Set<string>();
    const members = enumModel.Members.map((member) => {
        let name = member.Name;
        while (used.has(name)) name = `${name}_${member.Value}`;
        used.add(name);
        return name === member.Name ? member : { ...member, Name: name };
    });
    return { ...enumModel, Members: members };
}

/** Choices about the generated output that aren't part of `.dataverse-gen.json`. */
export interface GenerateOptions {
    /**
     * Rename later duplicate enum members (see {@link renameDuplicateEnumMembers}) instead of writing them as
     * dataverse-gen does, which TypeScript rejects.
     */
    renameDuplicateIdentifiers?: boolean;
}

export function generate(model: SchemaModel, config: ResolvedConfig, options: GenerateOptions = {}): GeneratedFile[] {
    const suffix = config.output.fileSuffix;
    const files: GeneratedFile[] = [];
    const add = (folder: string, name: string, content: string, duplicateIdentifiers: DuplicateIdentifier[] = []) => {
        files.push({ path: `${folder}/${name}${suffix}`, content, ...(duplicateIdentifiers.length > 0 && { duplicateIdentifiers }) });
    };

    for (const entity of model.entities) add(OUTPUT_FOLDERS.entities, entity.SchemaName, renderEntity(entity, config));
    for (const original of model.enums) {
        const enumModel = options.renameDuplicateIdentifiers ? renameDuplicateEnumMembers(original) : original;
        add(OUTPUT_FOLDERS.enums, enumModel.Name, renderEnum(enumModel), findDuplicateEnumMembers(enumModel));
    }
    for (const action of model.actions) add(OUTPUT_FOLDERS.actions, action.Name, renderOperation(action, 'action', config));
    for (const fn of model.functions) add(OUTPUT_FOLDERS.functions, fn.Name, renderOperation(fn, 'function', config));
    for (const complexType of model.complexTypes) add(OUTPUT_FOLDERS.complexTypes, complexType.Name, renderComplexType(complexType));

    files.push({ path: `metadata${suffix}`, content: renderMetadata(model) });
    if (config.generateIndex) {
        files.push({ path: `index${suffix}`, content: renderIndex(files.map((f) => f.path), suffix) });
    }
    return files;
}
