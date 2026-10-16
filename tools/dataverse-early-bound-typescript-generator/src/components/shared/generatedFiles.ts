import type { BadgeProps } from '@fluentui/react-components';
import type { FileStatus } from '../../types';

/** What a generated file contains, from its output folder (or name, for files at the output root). */
export type GeneratedFileType = 'entities' | 'enums' | 'actions' | 'functions' | 'metadata' | 'templates' | 'other';

const FOLDER_TYPES: Record<string, GeneratedFileType> = {
    entities: 'entities',
    enums: 'enums',
    actions: 'actions',
    functions: 'functions',
    // dataverse-gen's templates, in the project folder under the default templateRoot.
    _templates: 'templates',
};

/**
 * `entities/Account.ts` → `entities`; `metadata.ts` → `metadata`; `_templates/entity.ejs` → `templates`. Everything
 * else, including `complextypes/` and `index.ts`, is `other`.
 */
export function fileType(relativePath: string): GeneratedFileType {
    const slash = relativePath.indexOf('/');
    if (slash === -1) return /^metadata\./i.test(relativePath) ? 'metadata' : 'other';
    return FOLDER_TYPES[relativePath.substring(0, slash).toLowerCase()] ?? 'other';
}

/** The file name without its folder: `entities/Account.ts` → `Account.ts`. */
export const fileName = (relativePath: string) => relativePath.substring(relativePath.lastIndexOf('/') + 1);

/** How each status is shown: badge color and a one-line explanation of what Generate does. */
export const STATUS_META: Record<FileStatus, { color: NonNullable<BadgeProps['color']>; label: string; meaning: string }> = {
    new: { color: 'success', label: 'New', meaning: "Doesn't exist yet; Generate creates it." },
    changed: { color: 'warning', label: 'Changed', meaning: 'Content differs; Generate overwrites it.' },
    unchanged: { color: 'informative', label: 'Unchanged', meaning: 'Identical; not rewritten.' },
    orphaned: { color: 'danger', label: 'Orphaned', meaning: 'In the output folder but no longer generated; only reported, unless Delete orphaned files is on.' },
    duplicate: {
        color: 'severe',
        label: 'Duplicate identifiers',
        meaning:
            "Declares the same name more than once, so TypeScript won't compile it. Fix the option labels in Dataverse. Generate writes it when it's new or changed, unless Skip duplicated identifier(s) is on.",
    },
};

/** Status order used for sorting and the summary tiles. Files that won't compile come first. */
export const STATUS_ORDER: FileStatus[] = ['duplicate', 'new', 'changed', 'unchanged', 'orphaned'];
