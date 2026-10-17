import type { ProjectEntry } from '../../config';
import { basename, isSamePath } from '../../services';
import { formatRelativeTime } from '../shared/format';

/** How many recent projects the Project card offers by default. */
export const MAX_RECENT = 3;

/** A project folder to open, by name (for display) and location. */
export interface ProjectOpenTarget {
    name: string;
    location: string;
}

/** One entry in the card's recent-projects list. */
export interface RecentProject extends ProjectOpenTarget {
    key: string;
    /** Secondary line: "Last used" or "Modified 2 days ago". */
    meta: string;
    isLastUsed: boolean;
}

/**
 * Up to `max` projects to offer for reopening, excluding the open one: the folder last used with this
 * connection first, then saved projects by most recently modified. The last-used folder is shown under its
 * saved name when it's a saved project, and under its folder name otherwise.
 */
export function recentProjects(
    projects: ProjectEntry[],
    projectRoot: string | null,
    rememberedFolder: string | null,
    now: number,
    max = MAX_RECENT,
): RecentProject[] {
    const isOpen = (location: string) => !!projectRoot && isSamePath(location, projectRoot);
    const result: RecentProject[] = [];
    if (rememberedFolder && !isOpen(rememberedFolder)) {
        const saved = projects.find((p) => isSamePath(p.location, rememberedFolder));
        result.push({
            key: saved?.id ?? `last:${rememberedFolder}`,
            name: saved?.name ?? (basename(rememberedFolder) || rememberedFolder),
            location: saved?.location ?? rememberedFolder,
            meta: 'Last used',
            isLastUsed: true,
        });
    }
    const byModified = [...projects].sort((a, b) => (Date.parse(b.modifiedOn) || 0) - (Date.parse(a.modifiedOn) || 0));
    for (const p of byModified) {
        if (result.length >= max) break;
        if (isOpen(p.location) || result.some((r) => isSamePath(r.location, p.location))) continue;
        result.push({ key: p.id, name: p.name, location: p.location, meta: `Modified ${formatRelativeTime(p.modifiedOn, now)}`, isLastUsed: false });
    }
    return result.slice(0, max);
}
