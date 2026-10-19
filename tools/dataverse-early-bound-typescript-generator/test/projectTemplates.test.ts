/**
 * The custom enum template is configured per project (spec 001, Amendment 2), in `.dataverse-gen.json` under the
 * tool's own key, which the dataverse-gen CLI keeps and ignores.
 */
import { describe, expect, it } from 'vitest';
import { TOOL_CONFIG_KEY, parseConfig, projectCustomEnumTemplate, serializeConfig, withProjectCustomEnumTemplate, type DataverseGenConfig } from '../src/core';

describe('project custom enum template', () => {
    it('is undefined when the file has no value, so the default applies', () => {
        expect(projectCustomEnumTemplate({ entities: ['account'] })).toBeUndefined();
        expect(projectCustomEnumTemplate({ [TOOL_CONFIG_KEY]: {} })).toBeUndefined();
    });

    it('reads a boolean and ignores anything else', () => {
        expect(projectCustomEnumTemplate({ pptbEarlyBoundGenerator: { customEnumTemplate: true } })).toBe(true);
        expect(projectCustomEnumTemplate({ pptbEarlyBoundGenerator: { customEnumTemplate: false } })).toBe(false);
        expect(projectCustomEnumTemplate({ pptbEarlyBoundGenerator: { customEnumTemplate: 'yes' } })).toBeUndefined();
        expect(projectCustomEnumTemplate({ pptbEarlyBoundGenerator: 'on' })).toBeUndefined();
        expect(projectCustomEnumTemplate({ pptbEarlyBoundGenerator: [true] })).toBeUndefined();
    });

    it('writes the value without changing anything else', () => {
        const config: DataverseGenConfig = { entities: ['account'], output: { outputRoot: './gen' }, pptbEarlyBoundGenerator: { later: 1 } };
        const updated = withProjectCustomEnumTemplate(config, true);
        expect(updated).toEqual({ entities: ['account'], output: { outputRoot: './gen' }, pptbEarlyBoundGenerator: { later: 1, customEnumTemplate: true } });
        expect(config.pptbEarlyBoundGenerator).toEqual({ later: 1 });
        expect(projectCustomEnumTemplate(withProjectCustomEnumTemplate(updated, false))).toBe(false);
    });

    it('survives a save and load of .dataverse-gen.json', () => {
        const saved = serializeConfig(withProjectCustomEnumTemplate({ entities: ['account'] }, true));
        expect(saved).toContain('"pptbEarlyBoundGenerator": {\n    "customEnumTemplate": true\n  }');
        expect(projectCustomEnumTemplate(parseConfig(saved))).toBe(true);
    });
});
