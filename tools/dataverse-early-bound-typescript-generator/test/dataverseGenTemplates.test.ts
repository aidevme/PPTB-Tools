/// <reference types="node" />
// Node types for reading the bundled template files from disk; tsconfig keeps them out of src/.
/**
 * Generate writes dataverse-gen's EJS templates into the project's templateRoot (`_templates` by default), like
 * `npx dataverse-gen eject`, overwriting what's there. They come from dataverse-gen 2.0.17, byte for byte.
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { describe, expect, it } from 'vitest';
import { resolveConfig } from '../src/core';
import { fileType } from '../src/components/shared/generatedFiles';
import { DATAVERSE_GEN_TEMPLATES, dataverseGenTemplateFiles } from '../src/services/dataverseGenTemplates';
import { InMemoryFileSink } from '../src/services/fileSink';
import { applyWritePlan, createWritePlan } from '../src/services/plan';

const NAMES = ['action.ejs', 'complextype.ejs', 'entity.ejs', 'enum.ejs', 'function.ejs', 'index.ejs', 'metadata.ejs'];

describe('dataverse-gen templates', () => {
    it("are dataverse-gen's seven templates, byte for byte", () => {
        expect(DATAVERSE_GEN_TEMPLATES.map((t) => t.name)).toEqual(NAMES);
        const dir = path.join(__dirname, '..', 'src', 'assets', 'dataverse-gen-templates');
        for (const template of DATAVERSE_GEN_TEMPLATES) {
            expect(template.content).toBe(fs.readFileSync(path.join(dir, template.name), 'utf8'));
            // The originals use CRLF; .gitattributes keeps git from converting them.
            expect(template.content).toContain('\r\n');
        }
    });

    it('go under the templateRoot, _templates by default', () => {
        expect(dataverseGenTemplateFiles(resolveConfig({})).map((f) => f.path)).toEqual(NAMES.map((n) => `_templates/${n}`));
        expect(dataverseGenTemplateFiles(resolveConfig({ output: { templateRoot: '.\\tpl\\' } }))[0].path).toBe('tpl/action.ejs');
        expect(dataverseGenTemplateFiles(resolveConfig({ output: { templateRoot: '  ' } }))[0].path).toBe('_templates/action.ejs');
        expect(fileType('_templates/entity.ejs')).toBe('templates');
    });

    it('are written to the project folder on Generate, overwriting changed copies and never counted as orphans', async () => {
        const config = resolveConfig({ output: { outputRoot: './gen' } });
        const templates = dataverseGenTemplateFiles(config);
        const sink = new InMemoryFileSink({
            'C:\\proj\\_templates\\entity.ejs': 'my customised template',
            'C:\\proj\\_templates\\enum.ejs': templates.find((t) => t.path.endsWith('enum.ejs'))!.content.replace(/\r\n/g, '\n'),
        });
        const plan = await createWritePlan(sink, 'C:\\proj', config, [{ path: 'metadata.ts', content: 'M\n' }], templates);

        const byPath = Object.fromEntries(plan.files.filter((f) => f.inProjectFolder).map((f) => [f.relativePath, f.status]));
        expect(byPath['_templates/action.ejs']).toBe('new');
        expect(byPath['_templates/entity.ejs']).toBe('changed');
        // Line endings are ignored when comparing, as for the generated files.
        expect(byPath['_templates/enum.ejs']).toBe('unchanged');
        expect(plan.files.find((f) => f.relativePath === '_templates/action.ejs')?.absolutePath).toBe('C:\\proj\\_templates\\action.ejs');
        expect(plan.counts.orphaned).toBe(0);

        const result = await applyWritePlan(sink, plan);
        expect(result.written).toBe(7); // metadata.ts and six templates; enum.ejs was unchanged
        const action = templates.find((t) => t.path.endsWith('action.ejs'))!.content;
        expect(sink.files.get('C:\\proj\\_templates\\action.ejs')).toBe(action);
        expect(sink.files.get('C:\\proj\\_templates\\entity.ejs')).not.toBe('my customised template');
        expect(sink.files.get('C:\\proj\\gen\\metadata.ts')).toBe('M\n');
    });
});
