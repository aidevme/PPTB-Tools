/** Line diff used by the Preview card to show what Generate would change in a file. */
import { describe, expect, it } from 'vitest';
import { diffLines, type DiffLine } from '../src/components/shared/lineDiff';

const allLines = (text: string) => (text === '' ? [''] : text.split('\n'));
const flatten = (oldText: string, newText: string) => {
    const result = diffLines(oldText, newText, 100000)!;
    return { result, lines: result.blocks.flatMap((b) => (b.kind === 'lines' ? b.lines : [])) };
};

describe('diffLines', () => {
    it('rebuilds both texts from random diffs', () => {
        let seed = 7;
        const rnd = () => (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648;
        for (let t = 0; t < 500; t++) {
            const a = Array.from({ length: Math.floor(rnd() * 30) }, () => 'l' + Math.floor(rnd() * 6)).join('\n');
            const b = Array.from({ length: Math.floor(rnd() * 30) }, () => 'l' + Math.floor(rnd() * 6)).join('\n');
            const { result, lines } = flatten(a, b);
            if (a === b) {
                expect(result.added + result.removed).toBe(0);
                continue;
            }
            expect(lines.filter((l) => l.kind !== 'add').map((l) => l.text)).toEqual(allLines(a));
            expect(lines.filter((l) => l.kind !== 'remove').map((l) => l.text)).toEqual(allLines(b));
        }
    });

    it('numbers lines on both sides and counts changes', () => {
        const { result, lines } = flatten('a\nb\nc', 'a\nB\nc\nd');
        const view = (l: DiffLine) => `${l.kind[0]}${l.oldNumber ?? '-'}/${l.newNumber ?? '-'}:${l.text}`;
        expect(lines.map(view)).toEqual(['e1/1:a', 'r2/-:b', 'a-/2:B', 'e3/3:c', 'a-/4:d']);
        expect([result.added, result.removed]).toEqual([2, 1]);
    });

    it('ignores line endings and a trailing newline', () => {
        expect(diffLines('a\r\nb\r\n', 'a\nb')!.added).toBe(0);
    });

    it('keeps context around changes and collapses the rest', () => {
        const old = Array.from({ length: 20 }, (_, i) => `line ${i + 1}`);
        const changed = [...old];
        changed[9] = 'line 10 changed';
        const result = diffLines(old.join('\n'), changed.join('\n'), 2)!;
        expect(result.blocks.map((b) => (b.kind === 'skipped' ? `skip ${b.count}` : `lines ${b.lines.length}`))).toEqual(['skip 7', 'lines 6', 'skip 8']);
    });

    it('gives up on very large rewrites', () => {
        const a = Array.from({ length: 3000 }, (_, i) => `a${i}`).join('\n');
        const b = Array.from({ length: 3000 }, (_, i) => `b${i}`).join('\n');
        expect(diffLines(a, b)).toBeNull();
    });
});
