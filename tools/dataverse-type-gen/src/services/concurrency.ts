/**
 * Run `fn` over `items` with at most `limit` in flight at once, preserving result order. Used to keep
 * the number of parallel Dataverse metadata requests small (the guide recommends 4 to 6).
 */
export async function mapWithConcurrency<T, R>(
    items: readonly T[],
    limit: number,
    fn: (item: T, index: number) => Promise<R>,
    onProgress?: (completed: number, total: number, item: T) => void,
): Promise<R[]> {
    const results: R[] = new Array(items.length);
    let next = 0;
    let completed = 0;
    const workers = Array.from({ length: Math.max(1, Math.min(limit, items.length)) }, async () => {
        while (next < items.length) {
            const index = next++;
            results[index] = await fn(items[index], index);
            completed++;
            onProgress?.(completed, items.length, items[index]);
        }
    });
    await Promise.all(workers);
    return results;
}
