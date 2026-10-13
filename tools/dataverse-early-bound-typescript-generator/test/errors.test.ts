/**
 * Error handling: reading the HTTP status out of PPTB's error messages, friendly user messages, logging with
 * context plus a persistent error notification, and retrying transient failures.
 */
import { afterEach, describe, expect, it, vi } from 'vitest';
import { errorStatus, friendlyError, isTransientError, reportError, technicalMessage, withRetries, withRetry } from '../src/services/errors';

const ipc = (message: string) => new Error(`Error invoking remote method 'dataverse.queryData': Error: ${message}`);

afterEach(() => {
    delete (window as unknown as { toolboxAPI?: unknown }).toolboxAPI;
    vi.restoreAllMocks();
});

describe('reading errors', () => {
    it("strips PPTB's IPC prefix", () => {
        expect(technicalMessage(ipc('HTTP 503'))).toBe('HTTP 503');
        expect(technicalMessage('plain text')).toBe('plain text');
        expect(technicalMessage({ code: 1 })).toBe('{"code":1}');
    });

    it('finds the HTTP status in each format PPTB uses', () => {
        expect(errorStatus(ipc('HTTP 429'))).toBe(429);
        expect(errorStatus(new Error('Failed to retrieve CSDL document. Status: 401'))).toBe(401);
        expect(errorStatus(Object.assign(new Error('x'), { status: 404 }))).toBe(404);
        expect(errorStatus(ipc('0x80040220: Principal user is missing prvReadEntity privilege'))).toBe(403);
        expect(errorStatus(ipc('0x80072322: Combined execution time exceeded'))).toBe(429);
        expect(errorStatus(new Error('Something else'))).toBeUndefined();
    });

    it('treats throttling and unavailability as transient', () => {
        expect(isTransientError(ipc('HTTP 429'))).toBe(true);
        expect(isTransientError(ipc('HTTP 503'))).toBe(true);
        expect(isTransientError(ipc('HTTP 403'))).toBe(false);
        expect(isTransientError(new Error('Cannot create a Buffer larger than 16777216 bytes'))).toBe(false);
    });
});

describe('friendlyError', () => {
    it("uses the guide's message for known statuses", () => {
        expect(friendlyError(ipc('HTTP 403'))).toBe("You don't have permission to perform this action.");
        expect(friendlyError(ipc('0x80040217: account With Id = 1 Does Not Exist'))).toBe('Record not found. It may have been deleted.');
        expect(friendlyError(ipc('HTTP 401'))).toMatch(/reconnect/);
    });

    it('explains invalid JSON, folder access and network failures', () => {
        expect(friendlyError(new SyntaxError('Unexpected token } in JSON at position 12'))).toMatch(/isn't valid JSON/);
        expect(friendlyError(new Error('Access denied: C:\\repo'))).toMatch(/hasn't granted access/);
        expect(friendlyError(new Error('fetch failed'))).toMatch(/Couldn't reach Dataverse/);
    });

    it("keeps the tool's own messages, without the IPC prefix", () => {
        expect(friendlyError(ipc('account is not a Dataverse entity'))).toBe('account is not a Dataverse entity');
    });
});

describe('reportError', () => {
    it('logs with context, shows a persistent error notification and returns the bar text', () => {
        const error = vi.spyOn(console, 'error').mockImplementation(() => {});
        const showNotification = vi.fn(async () => {});
        (window as unknown as { toolboxAPI: unknown }).toolboxAPI = { utils: { showNotification } };

        const text = reportError('Could not list tables', ipc('HTTP 403'), { connection: 'dev' });
        expect(text).toBe("Could not list tables: You don't have permission to perform this action.");
        expect(showNotification).toHaveBeenCalledWith({
            title: 'Could not list tables',
            body: "You don't have permission to perform this action.",
            type: 'error',
            duration: 0,
        });
        const [label, details] = error.mock.calls[0] as [string, Record<string, unknown>];
        expect(label).toMatch(/^\[\d{4}-\d{2}-\d{2}T.*\] Could not list tables$/);
        expect(details).toMatchObject({ status: 403, connection: 'dev' });
    });

    it('can skip the notification, and never throws when the notification fails', async () => {
        vi.spyOn(console, 'error').mockImplementation(() => {});
        const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
        const showNotification = vi.fn(async () => Promise.reject(new Error('host closed')));
        (window as unknown as { toolboxAPI: unknown }).toolboxAPI = { utils: { showNotification } };

        reportError('Could not save the project', new Error('quota'), undefined, { notify: false });
        expect(showNotification).not.toHaveBeenCalled();

        expect(() => reportError('Preview failed', new Error('boom'))).not.toThrow();
        await new Promise((resolve) => setTimeout(resolve, 0));
        expect(warn).toHaveBeenCalled();
    });
});

describe('retries', () => {
    const sleep = vi.fn(async () => {});

    it('retries transient failures with growing delays, then succeeds', async () => {
        vi.spyOn(console, 'warn').mockImplementation(() => {});
        sleep.mockClear();
        const operation = vi.fn().mockRejectedValueOnce(ipc('HTTP 429')).mockRejectedValueOnce(ipc('HTTP 503')).mockResolvedValue('ok');
        await expect(withRetry(operation, { sleep })).resolves.toBe('ok');
        expect(operation).toHaveBeenCalledTimes(3);
        expect(sleep.mock.calls).toEqual([[500], [1000]]);
    });

    it('gives up after the last attempt, and never retries other errors', async () => {
        vi.spyOn(console, 'warn').mockImplementation(() => {});
        const throttled = vi.fn().mockRejectedValue(ipc('HTTP 429'));
        await expect(withRetry(throttled, { sleep })).rejects.toThrow('HTTP 429');
        expect(throttled).toHaveBeenCalledTimes(3);

        const forbidden = vi.fn().mockRejectedValue(ipc('HTTP 403'));
        await expect(withRetry(forbidden, { sleep })).rejects.toThrow('HTTP 403');
        expect(forbidden).toHaveBeenCalledTimes(1);
    });

    it('wraps every method of an API object', async () => {
        vi.spyOn(console, 'warn').mockImplementation(() => {});
        let calls = 0;
        const api = {
            name: 'stub',
            async queryData(query: string) {
                calls++;
                if (calls === 1) throw ipc('HTTP 503');
                return { query };
            },
        };
        const retrying = withRetries(api, { sleep });
        expect(retrying.name).toBe('stub');
        await expect(retrying.queryData('accounts')).resolves.toEqual({ query: 'accounts' });
        expect(calls).toBe(2);
    });
});
