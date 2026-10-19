/// <reference types="node" />
// Node types for reading the templates from disk; tsconfig keeps them out of src/.
/**
 * The custom enum template (spec 001) must make the dataverse-gen CLI write the same enum files as the tool with
 * duplicate renaming on. These tests render the templates with real EJS, as the CLI does
 * (`ejs.render(template, { ...options, ...enum })` in dataverse-gen 2.0.17), and compare the result with the tool's
 * renderer. See `specs/001-duplicate-identifier-templates/contracts/custom-enum-template.md`.
 *
 * Line endings: the templates use CRLF and the tool writes LF, so outputs are compared with CRLF normalised, as the
 * generator's reference tests do.
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { render } from 'ejs';
import { describe, expect, it } from 'vitest';
import { renameDuplicateEnumMembers, type EnumModel } from '../src/core';
import { renderEnum } from '../src/core/templates';

const assets = path.join(__dirname, '..', 'src', 'assets');
const originalTemplate = fs.readFileSync(path.join(assets, 'dataverse-gen-templates', 'enum.ejs'), 'utf8');
const customTemplate = fs.readFileSync(path.join(assets, 'custom-templates', 'enum.ejs'), 'utf8');

/** Renders an enum the way the dataverse-gen CLI does, with CRLF normalised. */
const cli = (template: string, enumModel: EnumModel) => render(template, { ...enumModel }).replace(/\r\n/g, '\n');

const MODELS: Record<string, EnumModel> = {
    'no duplicates': {
        Name: 'account_industrycode',
        StringMembers: false,
        Members: [
            { Name: 'Accounting', Value: '1' },
            { Name: 'Consulting', Value: '2' },
        ],
    },
    'one duplicate': {
        Name: 'incident_statuscode',
        StringMembers: false,
        Members: [
            { Name: 'InProgress', Value: '1' },
            { Name: 'OnHold', Value: '2' },
            { Name: 'InProgress', Value: '700970000' },
        ],
    },
    'a renamed name that is already taken': {
        Name: 'account_statuscode',
        StringMembers: false,
        Members: [
            { Name: 'Open', Value: '1' },
            { Name: 'Open', Value: '3' },
            { Name: 'Open_3', Value: '4' },
            { Name: 'Open', Value: '3' },
        ],
    },
    'names that are also object properties': {
        Name: 'new_choice',
        StringMembers: false,
        Members: [
            { Name: 'constructor', Value: '1' },
            { Name: 'toString', Value: '2' },
            { Name: 'toString', Value: '3' },
        ],
    },
    'string-valued members': {
        Name: 'EntityFilters',
        StringMembers: true,
        Members: [
            { Name: 'Entity', Value: '1' },
            { Name: 'Attributes', Value: '2' },
        ],
    },
};

describe('custom enum template', () => {
    it.each(Object.entries(MODELS))("makes the CLI write the tool's renamed output (%s)", (_name, model) => {
        expect(cli(customTemplate, model)).toBe(renderEnum(renameDuplicateEnumMembers(model)));
    });

    it.each(Object.entries(MODELS).filter(([, model]) => noDuplicates(model)))(
        'changes nothing when there are no duplicates (%s)',
        (_name, model) => {
            expect(cli(customTemplate, model)).toBe(cli(originalTemplate, model));
        },
    );

    it.each(Object.entries(MODELS))("control: dataverse-gen's own template matches the tool's renderer (%s)", (_name, model) => {
        expect(cli(originalTemplate, model)).toBe(renderEnum(model));
    });

    it('renames later duplicates to <Name>_<Value>, appending again while the name is taken', () => {
        const output = cli(customTemplate, MODELS['a renamed name that is already taken']);
        expect(output).toContain('  Open = 1,\n  Open_3 = 3,\n  Open_3_4 = 4,\n  Open_3_3 = 3,\n');
    });

    it('keeps dataverse-gen\'s line endings and its trailing "}\\r\\n  "', () => {
        expect(customTemplate).toContain('\r\n');
        expect(customTemplate.endsWith('}\r\n  ')).toBe(true);
    });
});

/** Whether no two members share a name. */
function noDuplicates(model: EnumModel): boolean {
    return new Set(model.Members.map((m) => m.Name)).size === model.Members.length;
}
