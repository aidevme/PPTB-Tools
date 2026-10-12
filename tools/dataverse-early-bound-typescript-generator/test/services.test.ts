import { describe, expect, it } from 'vitest';
import { resolveConfig, parseConfig, serializeConfig, createDefaultConfig } from '../src/core';
import { InMemoryFileSink } from '../src/services/fileSink';
import { basename, dirname, joinPath, separatorOf, toPosix } from '../src/services/paths';
import { applyWritePlan, createWritePlan } from '../src/services/plan';
import { loadProjectConfig, saveProjectConfig } from '../src/services/projectConfig';

describe('paths', () => {
    it('joins with the base path separator', () => {
        expect(joinPath('C:\\proj', './src/dataverse-gen', 'entities/Account.ts')).toBe('C:\\proj\\src\\dataverse-gen\\entities\\Account.ts');
        expect(joinPath('/home/me/proj', './src/dataverse-gen')).toBe('/home/me/proj/src/dataverse-gen');
        expect(joinPath('/home/me/proj/', '../other')).toBe('/home/me/other');
        expect(joinPath('C:\\proj\\', '..\\..\\..\\up')).toBe('C:\\up');
    });

    it('splits paths', () => {
        expect(separatorOf('C:\\x')).toBe('\\');
        expect(separatorOf('/x/y')).toBe('/');
        expect(dirname('C:\\a\\b\\c.ts')).toBe('C:\\a\\b');
        expect(dirname('/a/b/c.ts')).toBe('/a/b');
        expect(basename('/a/b/c.ts')).toBe('c.ts');
        expect(basename('C:\\a\\b\\')).toBe('b');
        expect(toPosix('.\\src\\x')).toBe('src/x');
    });
});

describe('config round-trip', () => {
    it('keeps unknown keys and dataverse-gen formatting', () => {
        const text = '{\n  "entities": ["account"],\n  "custom": { "x": 1 },\n  "output": { "outputRoot": "./gen", "templateRoot": "./tpl" }\n}';
        const config = parseConfig(text);
        expect(config.custom).toEqual({ x: 1 });
        const resolved = resolveConfig(config);
        expect(resolved.output.outputRoot).toBe('./gen');
        expect(resolved.output.templateRoot).toBe('./tpl');
        expect(resolved.output.fileSuffix).toBe('.ts');
        expect(resolved.generateIndex).toBe(true);
        expect(resolved.referencedTypes.Guid).toEqual({ name: 'Guid', import: 'dataverse-ify' });
        expect(serializeConfig(config)).toBe(JSON.stringify(config, null, 2) + '\n');
    });

    it('rejects a non-array entities value', () => {
        expect(() => parseConfig('{ "entities": "account" }')).toThrow(/must be an array/);
    });

    it('loads defaults when the file is missing and saves them back', async () => {
        const sink = new InMemoryFileSink();
        await sink.createDirectory('C:\\proj');
        const state = await loadProjectConfig(sink, 'C:\\proj');
        expect(state.exists).toBe(false);
        expect(state.config).toEqual(createDefaultConfig());
        await saveProjectConfig(sink, 'C:\\proj', state.config);
        expect((await loadProjectConfig(sink, 'C:\\proj')).exists).toBe(true);
    });
});

describe('write plan', () => {
    const config = resolveConfig({ output: { outputRoot: './src/dataverse-gen' } });
    const generated = [
        { path: 'entities/Account.ts', content: 'A\n' },
        { path: 'enums/account_statecode.ts', content: 'E\n' },
        { path: 'metadata.ts', content: 'M\n' },
        { path: 'index.ts', content: 'I\n' },
    ];

    it('classifies new, changed, unchanged and orphaned files', async () => {
        const sink = new InMemoryFileSink({
            'C:\\proj\\src\\dataverse-gen\\entities\\Account.ts': 'A\r\n',
            'C:\\proj\\src\\dataverse-gen\\enums\\account_statecode.ts': 'old',
            'C:\\proj\\src\\dataverse-gen\\enums\\stale_enum.ts': 'x',
            'C:\\proj\\src\\dataverse-gen\\notes.ts': 'user file, not ours',
        });
        const plan = await createWritePlan(sink, 'C:\\proj', config, generated);
        const byPath = Object.fromEntries(plan.files.map((f) => [f.relativePath, f.status]));
        expect(byPath).toEqual({
            'entities/Account.ts': 'unchanged',
            'enums/account_statecode.ts': 'changed',
            'metadata.ts': 'new',
            'index.ts': 'new',
            'enums/stale_enum.ts': 'orphaned',
        });
        expect(plan.counts).toEqual({ new: 2, changed: 1, unchanged: 1, orphaned: 1 });
        expect(plan.outputRoot).toBe('C:\\proj\\src\\dataverse-gen');

        const result = await applyWritePlan(sink, plan);
        expect(result).toEqual({ written: 3, skipped: 2 });
        expect(sink.files.get('C:\\proj\\src\\dataverse-gen\\entities\\Account.ts')).toBe('A\r\n'); // untouched
        expect(sink.files.get('C:\\proj\\src\\dataverse-gen\\enums\\account_statecode.ts')).toBe('E\n');
        expect(sink.files.get('C:\\proj\\src\\dataverse-gen\\index.ts')).toBe('I\n');
    });

    it('reuses an existing file name that differs only by casing', async () => {
        const sink = new InMemoryFileSink({ '/p/src/dataverse-gen/entities/account.ts': 'old' });
        const plan = await createWritePlan(sink, '/p', config, [{ path: 'entities/Account.ts', content: 'new' }]);
        const file = plan.files[0];
        expect(file.relativePath).toBe('entities/account.ts');
        expect(file.status).toBe('changed');
        expect(file.generatedName).toBe('Account.ts');
        await applyWritePlan(sink, plan);
        expect(sink.files.get('/p/src/dataverse-gen/entities/account.ts')).toBe('new');
        expect(sink.files.has('/p/src/dataverse-gen/entities/Account.ts')).toBe(false);
    });

    it('rewrites barrel imports to the reused on-disk casing', async () => {
        const sink = new InMemoryFileSink({ '/p/src/dataverse-gen/entities/account.ts': 'old' });
        const plan = await createWritePlan(sink, '/p', config, [
            { path: 'entities/Account.ts', content: 'A' },
            { path: 'metadata.ts', content: 'import { accountMetadata } from "./entities/Account";' },
            { path: 'index.ts', content: 'export * from "./entities/Account";\n' },
        ]);
        const byPath = Object.fromEntries(plan.files.map((f) => [f.relativePath, f.content]));
        expect(byPath['metadata.ts']).toBe('import { accountMetadata } from "./entities/account";');
        expect(byPath['index.ts']).toBe('export * from "./entities/account";\n');
    });

    it('creates the output folders on first generation', async () => {
        const sink = new InMemoryFileSink();
        await sink.createDirectory('/p');
        const plan = await createWritePlan(sink, '/p', config, generated);
        expect(plan.counts.new).toBe(4);
        await applyWritePlan(sink, plan);
        expect(sink.directories.has('/p/src/dataverse-gen/entities')).toBe(true);
        expect(sink.files.size).toBe(4);
    });
});
