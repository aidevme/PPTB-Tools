/**
 * How the Load Existing Project dialog orders saved projects: versions by number, dates by time, text without
 * case, ties by name. Plus the short date format and the shared text comparison.
 */
import { describe, expect, it } from 'vitest';
import type { ProjectEntry } from '../src/config';
import { compareDates, compareVersions, sortProjects } from '../src/components/dialogs/projectColumns';
import { formatDateTime } from '../src/components/shared/format';
import { compareText } from '../src/components/shared/sorting';

const project = (change: Partial<ProjectEntry>): ProjectEntry => ({
    id: change.name ?? 'p',
    name: 'Project',
    description: '',
    location: '/src/project',
    version: '1.0.0',
    createdOn: '2026-10-01T00:00:00.000Z',
    modifiedOn: '2026-10-01T00:00:00.000Z',
    ...change,
});

describe('compareVersions', () => {
    it('compares dotted numbers by value', () => {
        expect(compareVersions('1.0.9', '1.0.10')).toBeLessThan(0);
        expect(compareVersions('2.0', '1.9.9')).toBeGreaterThan(0);
        expect(compareVersions('1.0', '1.0.0')).toBe(0);
    });

    it('falls back to text order for anything else', () => {
        expect(compareVersions('beta', 'alpha')).toBeGreaterThan(0);
        expect(compareVersions('1.0.0', 'next')).toBeLessThan(0);
    });
});

describe('compareDates', () => {
    it('compares by time, and counts a value that is not a date as the earliest', () => {
        expect(compareDates('2026-01-01T00:00:00Z', '2026-02-01T00:00:00Z')).toBeLessThan(0);
        expect(compareDates('not a date', '2026-01-01T00:00:00Z')).toBeLessThan(0);
    });
});

describe('sortProjects', () => {
    const alpha = project({ name: 'alpha', version: '1.0.10' });
    const beta = project({ name: 'Beta', version: '1.0.9' });
    const gamma = project({ name: 'gamma', version: '1.0.9' });

    it('sorts by the column in either direction, without changing the input', () => {
        const projects = [gamma, alpha, beta];
        expect(sortProjects(projects, { column: 'name', direction: 'ascending' }).map((p) => p.name)).toEqual(['alpha', 'Beta', 'gamma']);
        expect(sortProjects(projects, { column: 'version', direction: 'descending' }).map((p) => p.name)).toEqual(['alpha', 'Beta', 'gamma']);
        expect(projects.map((p) => p.name)).toEqual(['gamma', 'alpha', 'Beta']);
    });

    it('keeps name order for ties', () => {
        expect(sortProjects([gamma, beta, alpha], { column: 'version', direction: 'ascending' }).map((p) => p.name)).toEqual(['Beta', 'gamma', 'alpha']);
    });
});

describe('formatDateTime and compareText', () => {
    it('returns text that is not a date unchanged', () => {
        expect(formatDateTime('unknown')).toBe('unknown');
        expect(formatDateTime('2026-10-17T12:00:00.000Z')).not.toBe('2026-10-17T12:00:00.000Z');
    });

    it('ignores case and compares numbers by value', () => {
        expect(compareText('Item', 'item')).toBe(0);
        expect(compareText('item2', 'item10')).toBeLessThan(0);
    });
});
