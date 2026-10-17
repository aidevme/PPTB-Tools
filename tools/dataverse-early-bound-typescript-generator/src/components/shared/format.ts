const UNITS: Array<[Intl.RelativeTimeFormatUnit, number]> = [
    ['year', 365 * 24 * 60 * 60],
    ['month', 30 * 24 * 60 * 60],
    ['week', 7 * 24 * 60 * 60],
    ['day', 24 * 60 * 60],
    ['hour', 60 * 60],
    ['minute', 60],
];

/** A date and time in the user's locale, short style (for example `10/17/26, 2:05 PM`); `iso` unchanged when it isn't a date. */
export function formatDateTime(iso: string): string {
    const date = new Date(iso);
    return Number.isNaN(date.getTime()) ? iso : date.toLocaleString(undefined, { dateStyle: 'short', timeStyle: 'short' });
}

/**
 * "just now", "5 minutes ago", "yesterday", "3 weeks ago" … in the user's locale. Returns `iso` unchanged
 * when it isn't a date. `now` is a parameter so callers and tests get stable results.
 */
export function formatRelativeTime(iso: string, now: number = Date.now(), locale?: string): string {
    const time = Date.parse(iso);
    if (Number.isNaN(time)) return iso;
    const seconds = Math.round((time - now) / 1000);
    if (Math.abs(seconds) < 45) return 'just now';
    const format = new Intl.RelativeTimeFormat(locale, { numeric: 'auto' });
    for (const [unit, size] of UNITS) {
        if (Math.abs(seconds) >= size) return format.format(Math.round(seconds / size), unit);
    }
    return format.format(Math.round(seconds / 60) || -1, 'minute');
}

/**
 * Shortens a long path in the middle, keeping its root and last two segments, e.g.
 * `C:\repos\nexus-d365\d365-ce\Project\Client\clientjs` → `C:\…\Client\clientjs`. Paths within `max`
 * characters are returned unchanged.
 */
export function shortenPath(path: string, max = 48): string {
    if (path.length <= max) return path;
    const separator = path.includes('\\') ? '\\' : '/';
    const parts = path.split(separator);
    if (parts.length <= 3) return path;
    const head = parts[0] === '' ? `${separator}${parts[1]}` : parts[0];
    return [head, '…', ...parts.slice(-2)].join(separator);
}
