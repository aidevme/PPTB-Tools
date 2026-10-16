/**
 * Error handling, following PPTB's error-handling guide: log the full error with context, show users a short,
 * actionable message without technical details, notify them with a persistent error notification, and retry
 * transient failures (throttling, service unavailable) a few times with growing delays.
 *
 * PPTB passes Dataverse errors to tools as plain `Error`s whose message carries the detail:
 * `HTTP 403` (no readable body), `Status: 403` (the `$metadata` call), or `<code>: <message>` when Dataverse
 * sends an error body, e.g. `0x80040220: Principal user is missing prvReadEntity privilege`. Crossing PPTB's
 * process boundary adds an `Error invoking remote method '…': Error: ` prefix.
 */
import { notificationOptions } from './notifications';

/** User-facing message per HTTP status, from PPTB's error-handling guide. */
export const STATUS_MESSAGES: Record<number, string> = {
    400: 'Invalid request. Please check your data.',
    401: 'Authentication failed. Please reconnect to the environment in Power Platform ToolBox.',
    403: "You don't have permission to perform this action.",
    404: 'Record not found. It may have been deleted.',
    429: 'Too many requests. Please wait a moment and try again.',
    500: 'Server error. Please try again later.',
    502: 'Service temporarily unavailable. Please try again later.',
    503: 'Service temporarily unavailable. Please try again later.',
    504: 'The service took too long to respond. Please try again later.',
};

/** Well-known Dataverse error codes, mapped to the HTTP status they correspond to. */
const DATAVERSE_CODES: Record<string, number> = {
    '0x80040220': 403, // Principal user is missing a privilege
    '0x80042f09': 403, // No roles assigned to the user
    '0x80040217': 404, // Record does not exist
    '0x80072321': 429, // Service protection: number of requests exceeded
    '0x80072322': 429, // Service protection: combined execution time exceeded
    '0x80072326': 429, // Service protection: number of concurrent requests exceeded
};

/** Statuses worth retrying: throttling and temporary unavailability. */
const TRANSIENT_STATUSES = new Set([429, 502, 503, 504]);

/** The error's message without PPTB's IPC prefix, or a readable text for non-`Error` values. */
export function technicalMessage(error: unknown): string {
    let message: string;
    if (error instanceof Error) message = error.message;
    else if (typeof error === 'string') message = error;
    else {
        try {
            message = JSON.stringify(error);
        } catch {
            message = String(error);
        }
    }
    return message.replace(/^Error invoking remote method '[^']*': (?:Error: )?/, '');
}

/** The HTTP status behind an error, from a `status`/`statusCode` property, the message, or a known Dataverse code. */
export function errorStatus(error: unknown): number | undefined {
    const record = error as { status?: unknown; statusCode?: unknown } | null;
    for (const value of [record?.status, record?.statusCode]) {
        if (typeof value === 'number' && value >= 400 && value < 600) return value;
    }
    const message = technicalMessage(error);
    const fromText = /\bHTTP (\d{3})\b|\bStatus: (\d{3})\b|\bstatus(?: code)? (\d{3})\b/i.exec(message);
    if (fromText) return Number(fromText[1] ?? fromText[2] ?? fromText[3]);
    const code = /\b(0x[0-9a-f]{8})\b/i.exec(message)?.[1]?.toLowerCase();
    return code ? DATAVERSE_CODES[code] : undefined;
}

/** Whether retrying might help: throttling or a temporarily unavailable service. */
export function isTransientError(error: unknown): boolean {
    const status = errorStatus(error);
    return status !== undefined && TRANSIENT_STATUSES.has(status);
}

/**
 * A short, actionable message for users, without stack traces or raw payloads. Known HTTP statuses and Dataverse
 * codes use the guide's messages; file access and invalid JSON get their own; anything else falls back to the
 * error's own message, since the tool's own errors are already written for users.
 */
export function friendlyError(error: unknown): string {
    const status = errorStatus(error);
    if (status !== undefined && STATUS_MESSAGES[status]) return STATUS_MESSAGES[status];
    const message = technicalMessage(error);
    if (error instanceof SyntaxError || /\bJSON\b.*(position|token|parse)|Unexpected token/i.test(message)) {
        return ".dataverse-gen.json isn't valid JSON. Fix or remove it and try again.";
    }
    if (/access denied|permission denied|not permitted|EACCES|EPERM/i.test(message)) {
        return "Power Platform ToolBox hasn't granted access to that folder. Open the project again with Load Existing Project to grant access.";
    }
    if (/ENOTFOUND|ECONNREFUSED|ECONNRESET|ETIMEDOUT|network|fetch failed/i.test(message)) {
        return "Couldn't reach Dataverse. Check your connection and try again.";
    }
    return message;
}

/**
 * Handles a failed operation: logs the full error with the operation, any context and a timestamp; shows a
 * persistent error notification titled with the operation (best effort); and returns
 * `"<operation>: <friendly message>"` for the page's error bar. Pass `notify: false` where the error is already
 * shown in place, such as inside a dialog.
 */
export function reportError(operation: string, error: unknown, context?: Record<string, unknown>, options: { notify?: boolean } = {}): string {
    const message = friendlyError(error);
    console.error(`[${new Date().toISOString()}] ${operation}`, { status: errorStatus(error), ...context, error });
    const utils = window.toolboxAPI?.utils;
    if (utils && options.notify !== false) {
        utils.showNotification(notificationOptions('error', message, operation)).catch((notifyError: unknown) => {
            console.warn('Could not show the error notification', notifyError);
        });
    }
    return `${operation}: ${message}`;
}

const retryingProxies = new WeakMap<object, object>();

/**
 * A view of `api` whose methods run through {@link withRetry}, so every call retries transient failures. Non-function
 * properties pass through unchanged. One proxy is cached per underlying object.
 *
 * The proxy wraps an empty object and reads from `api`, rather than wrapping `api` itself: PPTB exposes its APIs
 * through Electron's contextBridge, which freezes them, and a proxy over a frozen object must return each
 * property's actual value, so returning a wrapped method from it throws on every call.
 */
export function withRetries<T extends object>(api: T, options?: RetryOptions): T {
    const cached = retryingProxies.get(api);
    if (cached && !options) return cached as T;
    const proxy = new Proxy({} as T, {
        get(_target, property) {
            const value = Reflect.get(api, property);
            if (typeof value !== 'function') return value;
            return (...args: unknown[]) => withRetry(() => Promise.resolve(value.apply(api, args)), options);
        },
        has: (_target, property) => Reflect.has(api, property),
    });
    if (!options) retryingProxies.set(api, proxy);
    return proxy;
}

/** PPTB's Dataverse API, with throttling and temporary-unavailability errors retried (see {@link withRetries}). */
export function dataverseApi(): typeof window.dataverseAPI {
    if (!window.dataverseAPI) throw new Error('The PPTB Dataverse API is not available (not running inside Power Platform ToolBox?)');
    return withRetries(window.dataverseAPI);
}

export interface RetryOptions {
    /** Total attempts, including the first. Default 3. */
    attempts?: number;
    /** Delay before the first retry in ms; doubles each retry. Default 500. */
    baseDelayMs?: number;
    /** Which errors to retry. Default: {@link isTransientError}. */
    shouldRetry?: (error: unknown) => boolean;
    /** Waits between attempts; a parameter so tests don't sleep. */
    sleep?: (ms: number) => Promise<void>;
}

const defaultSleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

/**
 * Runs `operation`, retrying transient failures with growing delays (500 ms, then 1 s by default). Other errors,
 * and the last transient one, are rethrown unchanged.
 */
export async function withRetry<T>(operation: () => Promise<T>, options: RetryOptions = {}): Promise<T> {
    const { attempts = 3, baseDelayMs = 500, shouldRetry = isTransientError, sleep = defaultSleep } = options;
    for (let attempt = 1; ; attempt++) {
        try {
            return await operation();
        } catch (error) {
            if (attempt >= attempts || !shouldRetry(error)) throw error;
            console.warn(`Retrying after a transient error (attempt ${attempt} of ${attempts})`, error);
            await sleep(baseDelayMs * 2 ** (attempt - 1));
        }
    }
}
