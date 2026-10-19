/** One line in a diff: kept, added in the new text, or removed from the old one. */
export interface DiffLine {
    /** `equal` for a line in both texts, `add` for one only in the new text, `remove` for one only in the old text. */
    kind: 'equal' | 'add' | 'remove';
    /** The line's content, without its line ending. */
    text: string;
    /** 1-based line number in the old text (`equal` and `remove`). */
    oldNumber?: number;
    /** 1-based line number in the new text (`equal` and `add`). */
    newNumber?: number;
}

/** A run of changed lines with surrounding context, or a marker for unchanged lines left out between runs. */
export type DiffBlock = { kind: 'lines'; lines: DiffLine[] } | { kind: 'skipped'; count: number };

/** The result of {@link diffLines}. */
export interface DiffResult {
    /** The diff in order: runs of changed lines with their context, and `skipped` markers between them. */
    blocks: DiffBlock[];
    /** Number of lines only in the new text. */
    added: number;
    /** Number of lines only in the old text. */
    removed: number;
}

/** Above this many differing lines the comparison stops, so a huge rewrite can't freeze the UI. */
const MAX_EDIT_DISTANCE = 2000;

const splitLines = (text: string) => text.replace(/\r\n?/g, '\n').replace(/\n$/, '').split('\n');

/**
 * Line diff of `oldText` → `newText` (Myers' algorithm), with `context` unchanged lines kept around each change
 * and longer unchanged runs collapsed into `skipped` blocks. Line endings are ignored. Returns `null` when the
 * texts differ in more than about 2000 lines.
 *
 * @remarks
 * The common prefix and suffix are matched directly; only the lines between them go through Myers' algorithm. A
 * trailing line ending doesn't count as an extra empty line.
 *
 * @param oldText - The text before the change (for example the file on disk).
 * @param newText - The text after the change (for example the generated content).
 * @param context - Unchanged lines kept before and after each changed line; 3 when omitted.
 * @returns The blocks with the added and removed line counts, or `null` when the edit distance passes the limit.
 */
export function diffLines(oldText: string, newText: string, context = 3): DiffResult | null {
    const a = splitLines(oldText);
    const b = splitLines(newText);

    // Common prefix and suffix are usually most of a generated file; only the middle needs the full algorithm.
    let prefix = 0;
    while (prefix < a.length && prefix < b.length && a[prefix] === b[prefix]) prefix++;
    let suffix = 0;
    while (suffix < a.length - prefix && suffix < b.length - prefix && a[a.length - 1 - suffix] === b[b.length - 1 - suffix]) suffix++;

    const middle = myers(a.slice(prefix, a.length - suffix), b.slice(prefix, b.length - suffix));
    if (!middle) return null;

    const lines: DiffLine[] = [];
    let oldNumber = 1;
    let newNumber = 1;
    const push = (kind: DiffLine['kind'], text: string) => {
        if (kind === 'equal') lines.push({ kind, text, oldNumber: oldNumber++, newNumber: newNumber++ });
        else if (kind === 'remove') lines.push({ kind, text, oldNumber: oldNumber++ });
        else lines.push({ kind, text, newNumber: newNumber++ });
    };
    for (let i = 0; i < prefix; i++) push('equal', a[i]);
    for (const [kind, text] of middle) push(kind, text);
    for (let i = a.length - suffix; i < a.length; i++) push('equal', a[i]);

    return {
        blocks: toBlocks(lines, context),
        added: lines.filter((l) => l.kind === 'add').length,
        removed: lines.filter((l) => l.kind === 'remove').length,
    };
}

/** Shortest edit script between two line arrays, or `null` past {@link MAX_EDIT_DISTANCE}. */
function myers(a: string[], b: string[]): Array<[DiffLine['kind'], string]> | null {
    const n = a.length;
    const m = b.length;
    if (n === 0 && m === 0) return [];
    const max = Math.min(n + m, MAX_EDIT_DISTANCE);
    const offset = max + 1;
    const v = new Int32Array(2 * max + 3);
    // trace[d] is `v` as it was before step d: what backtracking needs to find each step's predecessor.
    const trace: Int32Array[] = [];
    let done = false;
    for (let d = 0; d <= max && !done; d++) {
        trace.push(v.slice());
        for (let k = -d; k <= d; k += 2) {
            let x = k === -d || (k !== d && v[offset + k - 1] < v[offset + k + 1]) ? v[offset + k + 1] : v[offset + k - 1] + 1;
            let y = x - k;
            while (x < n && y < m && a[x] === b[y]) {
                x++;
                y++;
            }
            v[offset + k] = x;
            if (x >= n && y >= m) {
                done = true;
                break;
            }
        }
    }
    if (!done) return null;

    const edits: Array<[DiffLine['kind'], string]> = [];
    let x = n;
    let y = m;
    for (let d = trace.length - 1; d >= 0; d--) {
        const prev = trace[d];
        const k = x - y;
        const prevK = k === -d || (k !== d && prev[offset + k - 1] < prev[offset + k + 1]) ? k + 1 : k - 1;
        const prevX = prev[offset + prevK];
        const prevY = prevX - prevK;
        while (x > prevX && y > prevY) {
            x--;
            y--;
            edits.push(['equal', a[x]]);
        }
        if (d > 0) {
            if (x === prevX) edits.push(['add', b[prevY]]);
            else edits.push(['remove', a[prevX]]);
        }
        x = prevX;
        y = prevY;
    }
    return edits.reverse();
}

function toBlocks(lines: DiffLine[], context: number): DiffBlock[] {
    const keep = lines.map(() => false);
    lines.forEach((line, i) => {
        if (line.kind === 'equal') return;
        for (let j = Math.max(0, i - context); j <= Math.min(lines.length - 1, i + context); j++) keep[j] = true;
    });
    const blocks: DiffBlock[] = [];
    let i = 0;
    while (i < lines.length) {
        const start = i;
        const kept = keep[i];
        while (i < lines.length && keep[i] === kept) i++;
        blocks.push(kept ? { kind: 'lines', lines: lines.slice(start, i) } : { kind: 'skipped', count: i - start });
    }
    return blocks;
}
