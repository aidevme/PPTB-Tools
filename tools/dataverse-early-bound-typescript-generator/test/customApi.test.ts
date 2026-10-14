/// <reference types="node" />
// Node types for reading fixtures from disk; tsconfig keeps them out of src/, which runs in the PPTB tool frame.
/**
 * Custom APIs missing from `$metadata` (private ones) are built from their `customapi` record and request
 * parameters, then generated like any other action.
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { buildSchemaModel, generate, resolveConfig } from '../src/core';
import type { EntityMetadataInput } from '../src/core';
import { PptbMetadataProvider } from '../src/services/metadataProvider';

const fixturesDir = path.join(__dirname, 'fixtures');
const edmxXml = fs.readFileSync(path.join(fixturesDir, 'edmx.xml'), 'utf8');
const loadEntity = (name: string) =>
    (JSON.parse(fs.readFileSync(path.join(fixturesDir, `${name}-metadata.json`), 'utf8')) as { EntityMetadata: EntityMetadataInput[] }).EntityMetadata[0];

const CUSTOM_API_ID = '11111111-2222-3333-4444-555555555555';

function installDataverseStub() {
    (window as unknown as { dataverseAPI: unknown }).dataverseAPI = {
        getCSDLDocument: async () => edmxXml,
        queryData: async (query: string) => {
            if (query.startsWith('customapis?')) {
                return {
                    value: [
                        {
                            customapiid: CUSTOM_API_ID,
                            uniquename: 'contoso_EscalateQueueItem',
                            displayname: 'Escalate queue item',
                            isfunction: false,
                            isprivate: true,
                            bindingtype: 1,
                            boundentitylogicalname: 'queueitem',
                        },
                    ],
                };
            }
            if (query.startsWith('customapirequestparameters?')) {
                expect(query).toContain(`_customapiid_value eq ${CUSTOM_API_ID}`);
                return {
                    value: [
                        { uniquename: 'Reason', type: 10, isoptional: false },
                        { uniquename: 'Priority', type: 7, isoptional: true },
                        { uniquename: 'Assignee', type: 5, isoptional: true, logicalentityname: null },
                        { uniquename: 'Tags', type: 11, isoptional: true },
                    ],
                };
            }
            if (query.startsWith('customapiresponseproperties?')) {
                expect(query).toContain(`_customapiid_value eq ${CUSTOM_API_ID}`);
                return {
                    value: [
                        { uniquename: 'Succeeded', type: 0 },
                        { uniquename: 'EscalationId', type: 12 },
                    ],
                };
            }
            if (query.startsWith('workflows?')) return { value: [] };
            throw new Error('unexpected query ' + query);
        },
    };
}

afterEach(() => {
    delete (window as unknown as { dataverseAPI?: unknown }).dataverseAPI;
});

describe('custom APIs missing from $metadata', () => {
    it('are listed as selectable, private custom APIs', async () => {
        installDataverseStub();
        const operations = await new PptbMetadataProvider().listOperations();
        const op = operations.find((o) => o.name === 'contoso_EscalateQueueItem');
        expect(op).toMatchObject({ kind: 'action', isCustomApi: true, isPrivate: true, inMetadata: false, boundTo: 'queueitem', componentId: CUSTOM_API_ID });
    });

    it('are generated from the custom API definition', async () => {
        installDataverseStub();
        const provider = new PptbMetadataProvider();
        const config = resolveConfig({ actions: ['contoso_EscalateQueueItem'] });
        const schema = await provider.getSchemaForSelection(config.actions, config.functions);
        const model = buildSchemaModel(schema, config, loadEntity);
        const files = new Map(generate(model, config).map((f) => [f.path, f.content]));

        // The bound table is pulled into the selection automatically.
        expect(files.has('entities/QueueItem.ts')).toBe(true);
        const action = files.get('actions/contoso_EscalateQueueItem.ts') as string;
        expect(action).toContain('boundParameter: "entity",');
        expect(action).toContain('typeName: "mscrm.queueitem",');
        expect(action).toContain('operationType: OperationType.Action,');
        expect(action).toContain('  entity?: import("dataverse-ify").EntityReference | import("../entities/QueueItem").QueueItem;');
        expect(action).toContain('  Reason?: string;');
        expect(action).toContain('  Priority?: number;');
        expect(action).toContain('  Assignee?: any;');
        expect(action).toContain('  Tags?: string[];');
        expect(files.get('metadata.ts')).toContain('contoso_EscalateQueueItem: contoso_EscalateQueueItemMetadata,');

        // Response properties become the `<UniqueName>Response` complex type, as $metadata would publish it.
        const response = files.get('complextypes/contoso_EscalateQueueItemResponse.ts') as string;
        expect(response).toContain('export interface contoso_EscalateQueueItemResponse {');
        expect(response).toContain('  EscalationId?: import("dataverse-ify").Guid;');
        expect(response).toContain('  Succeeded?: boolean;');
    });

    it('leave the CSDL schema untouched when everything selected is in $metadata', async () => {
        installDataverseStub();
        const provider = new PptbMetadataProvider();
        const schema = await provider.getSchemaForSelection(['WinOpportunity'], []);
        expect(schema).toBe(await provider.getSchema());
    });
});
