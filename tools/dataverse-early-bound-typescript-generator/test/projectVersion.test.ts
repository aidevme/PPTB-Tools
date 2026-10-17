/**
 * A saved project's version and Modified on change when a Generate run adds files or stops producing files
 * the previous run did.
 */
import { describe, expect, it } from 'vitest';
import { bumpPatchVersion, mergeToolConfig, recordGeneration, type ProjectEntry } from '../src/config';
import { isSamePath } from '../src/services/paths';

const NOW = '2026-10-20T10:00:00.000Z';
const base: ProjectEntry = {
    id: 'p1',
    name: 'Contoso',
    description: '',
    location: String.raw`C:\src\contoso`,
    version: '1.0.0',
    createdOn: '2026-10-12T00:00:00.000Z',
    modifiedOn: '2026-10-12T00:00:00.000Z',
};

describe('bumpPatchVersion', () => {
    it('increments the patch number', () => {
        expect(bumpPatchVersion('1.0.0')).toBe('1.0.1');
        expect(bumpPatchVersion('2.3.9')).toBe('2.3.10');
    });

    it('starts over at 1.0.1 for versions it cannot read', () => {
        expect(bumpPatchVersion('v1')).toBe('1.0.1');
    });
});

describe('recordGeneration', () => {
    it('on the first run, bumps when files were created on disk', () => {
        const result = recordGeneration(base, { files: ['entities/Account.ts', 'index.ts'], newFiles: ['entities/Account.ts'] }, NOW);
        expect(result).toEqual({ ...base, version: '1.0.1', modifiedOn: NOW, lastGeneratedFiles: ['entities/Account.ts', 'index.ts'] });
    });

    it('on the first run with everything already on disk, only records the files', () => {
        const result = recordGeneration(base, { files: ['index.ts'], newFiles: [] }, NOW);
        expect(result).toEqual({ ...base, lastGeneratedFiles: ['index.ts'] });
    });

    it('bumps when a file is added or dropped compared with the previous run', () => {
        const previous = { ...base, lastGeneratedFiles: ['entities/Account.ts', 'index.ts'] };
        const added = recordGeneration(previous, { files: ['entities/Account.ts', 'entities/Contact.ts', 'index.ts'], newFiles: [] }, NOW);
        expect(added?.version).toBe('1.0.1');
        expect(added?.modifiedOn).toBe(NOW);

        const dropped = recordGeneration(previous, { files: ['index.ts'], newFiles: [] }, NOW);
        expect(dropped).toEqual({ ...base, version: '1.0.1', modifiedOn: NOW, lastGeneratedFiles: ['index.ts'] });
    });

    it('leaves the project alone when the same files are generated, even if their content changed', () => {
        const previous = { ...base, lastGeneratedFiles: ['entities/Account.ts', 'index.ts'] };
        expect(recordGeneration(previous, { files: ['index.ts', 'entities/Account.ts'], newFiles: [] }, NOW)).toBeUndefined();
    });

    it('compares against the previous run, not the disk, so a recreated file still counts once', () => {
        // A file deleted by hand and recreated is "new" on disk but was in the previous run.
        const previous = { ...base, lastGeneratedFiles: ['index.ts'] };
        expect(recordGeneration(previous, { files: ['index.ts'], newFiles: ['index.ts'] }, NOW)).toBeUndefined();
    });
});

describe('saved project file lists', () => {
    it('are kept when loading, and absent for projects never generated', () => {
        const loaded = mergeToolConfig({ projects: [{ ...base, lastGeneratedFiles: ['index.ts', 3] }, base] }).projects;
        expect(loaded[0].lastGeneratedFiles).toEqual(['index.ts']);
        expect('lastGeneratedFiles' in loaded[1]).toBe(false);
    });
});

describe('isSamePath', () => {
    it('ignores separators, trailing separators and Windows casing', () => {
        expect(isSamePath(String.raw`C:\src\contoso`, 'c:/src/Contoso/')).toBe(true);
        expect(isSamePath(String.raw`\\server\share\a`, String.raw`\\SERVER\share\a\ `.trim())).toBe(true);
        expect(isSamePath(String.raw`C:\src\contoso`, String.raw`C:\src\fabrikam`)).toBe(false);
    });

    it('keeps casing significant for POSIX paths', () => {
        expect(isSamePath('/home/me/app/', '/home/me/app')).toBe(true);
        expect(isSamePath('/home/me/App', '/home/me/app')).toBe(false);
    });
});
