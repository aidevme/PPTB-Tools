/**
 * Snapshot tests: the core must produce the same files as `npx dataverse-gen` for the same input.
 *
 * `test/reference/<case>/` was produced by running dataverse-gen 2.0.17 (MIT, Scott Durow) against the
 * fixtures in `test/fixtures/` (a trimmed copy of dataverse-gen's own test data), with CRLF normalised
 * to LF. `index.ts` is compared as an unordered set of export lines because dataverse-gen orders CSDL
 * enums with a comparator that is not a total order.
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { describe, expect, it } from 'vitest';
import { buildSchemaModel, generate, parseCsdl, resolveConfig, resolveSelection } from '../src/core';
import type { DataverseGenConfig, EntityMetadataInput } from '../src/core';

const fixturesDir = path.join(__dirname, 'fixtures');
const referenceDir = path.join(__dirname, 'reference');

const edmx = parseCsdl(fs.readFileSync(path.join(fixturesDir, 'edmx.xml'), 'utf8'));

function loadEntity(logicalName: string): EntityMetadataInput | undefined {
    const file = path.join(fixturesDir, `${logicalName}-metadata.json`);
    if (!fs.existsSync(file)) return undefined;
    const json = JSON.parse(fs.readFileSync(file, 'utf8')) as { EntityMetadata: EntityMetadataInput[] };
    return json.EntityMetadata[0];
}

function generateCase(config: DataverseGenConfig): Map<string, string> {
    const resolved = resolveConfig(config);
    const model = buildSchemaModel(edmx, resolved, loadEntity);
    return new Map(generate(model, resolved).map((f) => [f.path, f.content]));
}

function listReference(caseName: string): string[] {
    const root = path.join(referenceDir, caseName);
    const result: string[] = [];
    const walk = (dir: string) => {
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
            const full = path.join(dir, entry.name);
            if (entry.isDirectory()) walk(full);
            else result.push(path.relative(root, full).replace(/\\/g, '/'));
        }
    };
    walk(root);
    return result.sort();
}

function expectMatchesReference(caseName: string, files: Map<string, string>) {
    const expectedPaths = listReference(caseName);
    expect([...files.keys()].sort()).toEqual(expectedPaths);
    for (const relative of expectedPaths) {
        const expected = fs.readFileSync(path.join(referenceDir, caseName, relative), 'utf8');
        const actual = files.get(relative) as string;
        if (relative === 'index.ts') {
            expect(actual.split('\n').sort()).toEqual(expected.split('\n').sort());
        } else {
            expect(actual, relative).toBe(expected);
        }
    }
}

describe('CSDL parsing', () => {
    it('reads entity types, operations, complex types and enums', () => {
        expect(edmx.entityTypes.map((e) => e.Name)).toContain('queueitem');
        expect(edmx.entityTypes.find((e) => e.Name === 'crmbaseentity')).toBeUndefined();
        expect(edmx.entityTypes.find((e) => e.Name === 'account')?.EntitySetName).toBe('accounts');
        expect(edmx.entityTypes.find((e) => e.Name === 'account')?.KeyName).toBe('accountid');
        expect(edmx.actions.map((a) => a.Name)).toEqual(['LoseOpportunity', 'WinOpportunity']);
        expect(edmx.functions.map((f) => f.Name)).toEqual(['RetrieveMetadataChanges', 'WhoAmI']);
        expect(edmx.enumTypes.find((e) => e.Name === 'LogicalOperator')?.Members[0]).toEqual({ Name: 'And', Value: '0' });
        expect(edmx.functions.find((f) => f.Name === 'RetrieveMetadataChanges')?.Parameters.map((p) => p.Name)).toEqual([
            'Query',
            'DeletedMetadataFilters',
            'ClientVersionStamp',
            'AppModuleId',
            'RetrieveAllSettings',
        ]);
    });
});

describe('selection', () => {
    it('pulls in entities referenced by selected actions', () => {
        const selection = resolveSelection(edmx, resolveConfig({ entities: ['queueitem'], actions: ['WinOpportunity'] }));
        expect(selection.entities.map((e) => e.Name)).toEqual(['opportunityclose', 'queueitem']);
        expect(selection.complexTypes).toHaveLength(0);
    });

    it('pulls in complex types and enums transitively for functions', () => {
        const selection = resolveSelection(edmx, resolveConfig({ functions: ['RetrieveMetadataChanges'] }));
        expect(selection.complexTypes.map((c) => c.Name)).toContain('LocalizedLabel');
        expect(selection.enumTypes.map((e) => e.Name)).toContain('MetadataConditionOperator');
    });

    it('fails clearly when metadata for a required entity is missing', () => {
        const resolved = resolveConfig({ entities: ['activitypointer'] });
        expect(() => buildSchemaModel(edmx, resolved, loadEntity)).toThrow(/activitypointer is not a Dataverse entity/);
    });
});

describe('generated output matches dataverse-gen', () => {
    it('entities, actions, functions, enums, complex types, metadata and index', () => {
        const files = generateCase({
            entities: ['account', 'queueitem', 'cdsify_integrationtest'],
            actions: ['WinOpportunity'],
            functions: ['RetrieveMetadataChanges', 'WhoAmI'],
            output: { outputRoot: './x' },
        });
        expectMatchesReference('full', files);
    });

    it('form context without entity types or index', () => {
        const files = generateCase({
            entities: ['queueitem'],
            actions: [],
            functions: [],
            generateEntityTypes: false,
            generateFormContext: true,
            generateIndex: false,
            output: { outputRoot: './x' },
        });
        expectMatchesReference('noentitytypes', files);
    });

    it('honours a custom file suffix', () => {
        const files = generateCase({ entities: ['queueitem'], output: { fileSuffix: '.d.ts' } });
        expect([...files.keys()]).toContain('entities/QueueItem.d.ts');
        expect(files.get('index.d.ts')).toContain('export * from "./entities/QueueItem";');
    });
});
