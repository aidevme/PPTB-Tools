/** Per-line result of {@link diffLines}: whether a line participates in the longest common subsequence
 * between the two sides ("same") or not ("changed"). */
export type DiffLineStatus = "same" | "changed";

function computeLcsGrid(a: string[], b: string[]): number[][] {
    const n = a.length;
    const m = b.length;
    const grid: number[][] = Array.from({ length: n + 1 }, () => new Array<number>(m + 1).fill(0));
    for (let i = n - 1; i >= 0; i--) {
        for (let j = m - 1; j >= 0; j--) {
            grid[i][j] = a[i] === b[j] ? grid[i + 1][j + 1] + 1 : Math.max(grid[i + 1][j], grid[i][j + 1]);
        }
    }
    return grid;
}

/**
 * Classic LCS-based line diff (the same idea `diff`/`git diff` use): lines that participate in the
 * longest common subsequence are "same", everything else is "changed" — on the `a` side that means
 * "removed", on the `b` side that means "added".
 */
export function diffLines(a: string[], b: string[]): { a: DiffLineStatus[]; b: DiffLineStatus[] } {
    const grid = computeLcsGrid(a, b);
    const aStatus: DiffLineStatus[] = new Array(a.length).fill("changed");
    const bStatus: DiffLineStatus[] = new Array(b.length).fill("changed");

    let i = 0;
    let j = 0;
    while (i < a.length && j < b.length) {
        if (a[i] === b[j]) {
            aStatus[i] = "same";
            bStatus[j] = "same";
            i++;
            j++;
        } else if (grid[i + 1][j] >= grid[i][j + 1]) {
            i++;
        } else {
            j++;
        }
    }

    return { a: aStatus, b: bStatus };
}
