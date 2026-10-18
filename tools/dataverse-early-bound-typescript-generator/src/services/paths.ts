/**
 * Tiny path helper for the PPTB file-system API, which only accepts absolute paths and uses the host
 * OS's separator. The generator core only deals in forward-slash relative paths; this module turns
 * them into host paths relative to the project folder the user picked.
 */

/** Separator in use for a given absolute path (`\` for Windows drive / UNC paths, `/` otherwise). */
export function separatorOf(absolutePath: string): '\\' | '/' {
    return /^[a-zA-Z]:|^\\\\/.test(absolutePath) || (absolutePath.includes('\\') && !absolutePath.includes('/')) ? '\\' : '/';
}

/** Normalise `./a/b\c/../d` style segments relative to nothing (keeps leading `..`). */
function normalizeSegments(segments: string[]): string[] {
    const out: string[] = [];
    for (const segment of segments) {
        if (segment === '' || segment === '.') continue;
        if (segment === '..') {
            if (out.length > 0 && out[out.length - 1] !== '..') out.pop();
            else out.push('..');
            continue;
        }
        out.push(segment);
    }
    return out;
}

/** Join an absolute base path with one or more relative parts, using the base path's separator. */
export function joinPath(base: string, ...parts: string[]): string {
    const sep = separatorOf(base);
    const trimmedBase = base.replace(/[\\/]+$/, '');
    const relative = normalizeSegments(parts.flatMap((p) => p.split(/[\\/]+/)));
    const baseSegments = trimmedBase.split(/[\\/]/);
    // Resolve `..` against the base too, but never above the root segment (drive letter or empty for `/`).
    const root = baseSegments[0];
    const merged = normalizeSegments([...baseSegments.slice(1), ...relative]).filter((s) => s !== '..');
    const joined = [root, ...merged].join(sep);
    return joined === '' ? sep : joined;
}

/** Returns the parent folder of an absolute path, ignoring trailing separators. */
export function dirname(absolutePath: string): string {
    const sep = separatorOf(absolutePath);
    const trimmed = absolutePath.replace(/[\\/]+$/, '');
    const index = Math.max(trimmed.lastIndexOf('\\'), trimmed.lastIndexOf('/'));
    if (index <= 0) return trimmed.substring(0, index + 1) || sep;
    return trimmed.substring(0, index);
}

/** Returns the last segment of a path (a file or folder name), ignoring trailing separators. */
export function basename(absolutePath: string): string {
    const trimmed = absolutePath.replace(/[\\/]+$/, '');
    const index = Math.max(trimmed.lastIndexOf('\\'), trimmed.lastIndexOf('/'));
    return trimmed.substring(index + 1);
}

/** Forward-slash form of a relative path, for display and for the core. */
export function toPosix(relativePath: string): string {
    return relativePath.replace(/\\/g, '/').replace(/^\.\//, '');
}

/**
 * Whether two absolute paths name the same folder, ignoring separators and trailing separators, and casing
 * for Windows paths (drive letter or UNC).
 */
export function isSamePath(a: string, b: string): boolean {
    const normalize = (p: string) => {
        const slashed = p.trim().replace(/\\/g, '/').replace(/\/+$/, '');
        return separatorOf(p) === '\\' ? slashed.toLowerCase() : slashed;
    };
    return normalize(a) === normalize(b);
}
