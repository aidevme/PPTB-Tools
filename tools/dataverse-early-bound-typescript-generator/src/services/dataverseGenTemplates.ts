/**
 * dataverse-gen's EJS templates, written into the project on every Generate like `npx dataverse-gen eject` does.
 *
 * The files are dataverse-gen 2.0.17's `_templates`, copied byte for byte (MIT, see THIRD_PARTY_NOTICES.md). This
 * tool doesn't read them: it can't run EJS inside PPTB, so its generator reimplements them in `core/templates.ts`.
 * They're there for the dataverse-gen CLI, which uses templates found in the project's `templateRoot` in place of
 * its built-in ones.
 */
import type { GeneratedFile, ResolvedConfig } from '../core';
import action from '../assets/dataverse-gen-templates/action.ejs?raw';
import complextype from '../assets/dataverse-gen-templates/complextype.ejs?raw';
import entity from '../assets/dataverse-gen-templates/entity.ejs?raw';
import enumTemplate from '../assets/dataverse-gen-templates/enum.ejs?raw';
import functionTemplate from '../assets/dataverse-gen-templates/function.ejs?raw';
import index from '../assets/dataverse-gen-templates/index.ejs?raw';
import metadata from '../assets/dataverse-gen-templates/metadata.ejs?raw';
import customEnumTemplate from '../assets/custom-templates/enum.ejs?raw';
import { toPosix } from './paths';

/** dataverse-gen's default `templateRoot`, used when the config leaves it blank. */
export const DEFAULT_TEMPLATE_ROOT = './_templates';

/** The templates by file name, in dataverse-gen's folder order. */
export const DATAVERSE_GEN_TEMPLATES: ReadonlyArray<{ name: string; content: string }> = [
    { name: 'action.ejs', content: action },
    { name: 'complextype.ejs', content: complextype },
    { name: 'entity.ejs', content: entity },
    { name: 'enum.ejs', content: enumTemplate },
    { name: 'function.ejs', content: functionTemplate },
    { name: 'index.ejs', content: index },
    { name: 'metadata.ejs', content: metadata },
];

/**
 * The custom `enum.ejs`: dataverse-gen's, plus renaming of later duplicate members to `<Name>_<Value>`, the rule
 * `renameDuplicateEnumMembers` applies, so the dataverse-gen CLI writes the same names as the tool (spec 001).
 */
export const CUSTOM_ENUM_TEMPLATE: string = customEnumTemplate;

/** Options for {@link dataverseGenTemplateFiles}. */
export interface TemplateFileOptions {
    /**
     * Write the custom `enum.ejs` ({@link CUSTOM_ENUM_TEMPLATE}) in place of dataverse-gen's; the other six templates
     * are unchanged.
     * @defaultValue false
     */
    customEnum?: boolean;
}

/**
 * The template files to write, with paths relative to the project folder (not the output folder), under the
 * config's `templateRoot`: `_templates/action.ejs` and so on by default.
 *
 * @param config - The project's resolved config; its `output.templateRoot` picks the folder.
 * @param options - Whether to write the custom `enum.ejs`.
 * @returns The seven template files, in dataverse-gen's order.
 */
export function dataverseGenTemplateFiles(config: ResolvedConfig, options: TemplateFileOptions = {}): GeneratedFile[] {
    const root = toPosix(config.output.templateRoot?.trim() || DEFAULT_TEMPLATE_ROOT).replace(/\/+$/, '');
    return DATAVERSE_GEN_TEMPLATES.map((t) => ({
        path: root && root !== '.' ? `${root}/${t.name}` : t.name,
        content: options.customEnum && t.name === 'enum.ejs' ? CUSTOM_ENUM_TEMPLATE : t.content,
    }));
}
