/// <reference types="node" />
// Node types for reading fixtures from disk; tsconfig keeps them out of src/, which runs in the PPTB tool frame.
/**
 * Fallback for environments whose `$metadata` document is too large for PPTB's `getCSDLDocument`: the schema
 * is rebuilt from table and relationship metadata instead of the CSDL.
 *
 * The fidelity tests turn the fixture CSDL's navigation properties into the relationship metadata Dataverse
 * reports for them, then check that the fallback produces the same navigation and the same entity files as
 * the CSDL path (and so as dataverse-gen's reference output).
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { buildSchemaModel, createMetadataSchema, generate, navigationFromRelationships, parseCsdl, resolveConfig } from '../src/core';
import type { EdmxEntityType, EntityMetadataInput, OneToManyRelationshipInput } from '../src/core';
import { PptbMetadataProvider } from '../src/services/metadataProvider';

const fixturesDir = path.join(__dirname, 'fixtures');
const referenceDir = path.join(__dirname, 'reference', 'full');
const edmx = parseCsdl(fs.readFileSync(path.join(fixturesDir, 'edmx.xml'), 'utf8'));

const PPTB_SIZE_ERROR =
    "Error invoking remote method 'dataverse.getCSDLDocument': Error: Get CSDL document failed: Failed to decompress metadata response: Cannot create a Buffer larger than 16777216 bytes";

/** The relationship metadata Dataverse reports for the navigation properties the CSDL declares on `entityType`. */
function relationshipsFor(entityType: EdmxEntityType): Pick<EntityMetadataInput, 'ManyToOneRelationships' | 'OneToManyRelationships'> {
    const manyToOne: OneToManyRelationshipInput[] = [];
    const oneToMany: OneToManyRelationshipInput[] = [];
    for (const n of entityType.NavigationProperties) {
        if (n.IsCollection) {
            oneToMany.push({ ReferencedEntity: entityType.Name, ReferencingEntity: n.LogicalName, ReferencedEntityNavigationPropertyName: n.Name });
        } else {
            // Owner lookups reference the `owner` entity in metadata; the CSDL types them as `principal`.
            const referenced = n.LogicalName === 'principal' ? 'owner' : n.LogicalName;
            manyToOne.push({ ReferencingEntity: entityType.Name, ReferencedEntity: referenced, ReferencingEntityNavigationPropertyName: n.Name });
        }
    }
    return { ManyToOneRelationships: manyToOne, OneToManyRelationships: oneToMany };
}

function loadEntityWithRelationships(logicalName: string): EntityMetadataInput | undefined {
    const file = path.join(fixturesDir, `${logicalName}-metadata.json`);
    if (!fs.existsSync(file)) return undefined;
    const metadata = (JSON.parse(fs.readFileSync(file, 'utf8')) as { EntityMetadata: EntityMetadataInput[] }).EntityMetadata[0];
    const entityType = edmx.entityTypes.find((e) => e.Name === logicalName);
    // The provider always loads PrimaryIdAttribute; dataverse-gen's fixtures don't include it, and the
    // fallback schema has no CSDL key to fall back on, so take it from the fixture CSDL.
    return entityType ? { ...metadata, PrimaryIdAttribute: entityType.KeyName, ...relationshipsFor(entityType) } : metadata;
}

describe('navigation from relationships', () => {
    it('matches the navigation properties the CSDL declares', () => {
        for (const name of ['account', 'queueitem', 'cdsify_integrationtest']) {
            const entityType = edmx.entityTypes.find((e) => e.Name === name) as EdmxEntityType;
            const metadata = loadEntityWithRelationships(name) as EntityMetadataInput;
            const simplify = (n: { Name: string; Type: string; IsCollection: boolean }) => ({ Name: n.Name, Type: n.Type, IsCollection: n.IsCollection });
            expect(navigationFromRelationships(metadata).map(simplify), name).toEqual(entityType.NavigationProperties.map(simplify));
        }
    });

    it('maps owner lookups to principal and covers both sides of many-to-many', () => {
        const nav = navigationFromRelationships({
            LogicalName: 'contact',
            SchemaName: 'Contact',
            EntitySetName: 'contacts',
            Attributes: [],
            ManyToOneRelationships: [
                { ReferencingEntity: 'contact', ReferencedEntity: 'owner', ReferencingEntityNavigationPropertyName: 'ownerid' },
                { ReferencingEntity: 'contact', ReferencedEntity: 'account', ReferencingEntityNavigationPropertyName: null },
                // Duplicates and rows for the other side are ignored.
                { ReferencingEntity: 'contact', ReferencedEntity: 'owner', ReferencingEntityNavigationPropertyName: 'ownerid' },
                { ReferencingEntity: 'task', ReferencedEntity: 'contact', ReferencingEntityNavigationPropertyName: 'regardingobjectid_contact_task' },
            ],
            ManyToManyRelationships: [
                { Entity1LogicalName: 'contact', Entity2LogicalName: 'list', Entity1NavigationPropertyName: 'listcontact_association', Entity2NavigationPropertyName: 'x' },
                { Entity1LogicalName: 'contact', Entity2LogicalName: 'contact', Entity1NavigationPropertyName: 'related_a', Entity2NavigationPropertyName: 'related_b' },
            ],
        });
        expect(nav.map((n) => [n.Name, n.Type, n.IsCollection])).toEqual([
            ['listcontact_association', 'mscrm.list', true],
            ['ownerid', 'mscrm.principal', false],
            ['related_a', 'mscrm.contact', true],
            ['related_b', 'mscrm.contact', true],
        ]);
    });
});

describe('schema rebuilt from metadata', () => {
    it('has one entity type per table plus the abstract base types, and no operations', () => {
        const schema = createMetadataSchema([
            { logicalName: 'contact', entitySetName: 'contacts' },
            { logicalName: 'account', entitySetName: 'accounts' },
        ]);
        expect(schema.source).toBe('metadata');
        expect(schema.entityTypes.map((e) => e.Name)).toEqual(['account', 'contact', 'crmbaseentity', 'principal']);
        expect(schema.entityTypes[0].EntitySetName).toBe('accounts');
        expect([schema.actions, schema.functions, schema.complexTypes, schema.enumTypes]).toEqual([[], [], [], []]);
    });

    it('generates the same entity files as the CSDL path', () => {
        const config = resolveConfig({ entities: ['account', 'queueitem', 'cdsify_integrationtest'], output: { outputRoot: './x' } });
        const schema = createMetadataSchema(edmx.entityTypes.filter((e) => !e.Abstract).map((e) => ({ logicalName: e.Name, entitySetName: e.EntitySetName })));
        const files = generate(buildSchemaModel(schema, config, loadEntityWithRelationships), config);

        const entityFiles = files.filter((f) => f.path.startsWith('entities/') || f.path.startsWith('enums/'));
        expect(entityFiles.map((f) => f.path)).toContain('entities/Account.ts');
        for (const file of entityFiles) {
            expect(file.content, file.path).toBe(fs.readFileSync(path.join(referenceDir, file.path), 'utf8'));
        }
    });
});

describe('metadata provider fallback', () => {
    const relationshipCalls: string[] = [];

    function installStub(csdlError: string) {
        relationshipCalls.length = 0;
        (window as unknown as { dataverseAPI: unknown }).dataverseAPI = {
            getCSDLDocument: async () => {
                throw new Error(csdlError);
            },
            getAllEntitiesMetadata: async () => ({
                value: [{ LogicalName: 'account', SchemaName: 'Account', EntitySetName: 'accounts', MetadataId: 'a', DisplayName: null }],
            }),
            getEntityMetadata: async () => ({ LogicalName: 'account', SchemaName: 'Account', EntitySetName: 'accounts', PrimaryIdAttribute: 'accountid' }),
            getEntityRelatedMetadata: async (_name: string, relatedPath: string) => {
                if (relatedPath === 'Attributes') {
                    return { value: [{ LogicalName: 'name', SchemaName: 'Name', AttributeTypeName: { Value: 'StringType' } }] };
                }
                relationshipCalls.push(relatedPath);
                if (relatedPath === 'ManyToOneRelationships') {
                    return { value: [{ ReferencingEntity: 'account', ReferencedEntity: 'owner', ReferencingEntityNavigationPropertyName: 'ownerid' }] };
                }
                return { value: [] };
            },
            queryData: async (query: string) => {
                if (query.startsWith('customapis?')) {
                    return {
                        value: [{ customapiid: 'c1', uniquename: 'contoso_Ping', displayname: 'Ping', isfunction: false, isprivate: false, bindingtype: 0 }],
                    };
                }
                if (query.startsWith('customapirequestparameters?') || query.startsWith('customapiresponseproperties?') || query.startsWith('workflows?')) {
                    return { value: [] };
                }
                throw new Error('unexpected query ' + query);
            },
        };
    }

    afterEach(() => {
        delete (window as unknown as { dataverseAPI?: unknown }).dataverseAPI;
    });

    it('rebuilds the schema from table metadata when the CSDL is too large', async () => {
        installStub(PPTB_SIZE_ERROR);
        const provider = new PptbMetadataProvider();
        const schema = await provider.getSchema();
        expect(provider.usesMetadataFallback).toBe(true);
        expect(schema.source).toBe('metadata');
        expect(schema.entityTypes.map((e) => e.Name)).toContain('account');

        // Custom APIs are still listed and built from their definitions.
        const operations = await provider.listOperations();
        expect(operations).toEqual([expect.objectContaining({ name: 'contoso_Ping', kind: 'action', isCustomApi: true, inMetadata: false })]);
        const forSelection = await provider.getSchemaForSelection(['contoso_Ping'], []);
        expect(forSelection.source).toBe('metadata');
        expect(forSelection.actions.map((a) => a.Name)).toEqual(['contoso_Ping']);

        // Entities carry their relationships, which become the navigation.
        const account = await provider.getEntity('account');
        expect(relationshipCalls.sort()).toEqual(['ManyToManyRelationships', 'ManyToOneRelationships', 'OneToManyRelationships']);
        expect(navigationFromRelationships(account).map((n) => [n.Name, n.Type])).toEqual([['ownerid', 'mscrm.principal']]);
    });

    it('also falls back when the compressed download is over the limit', async () => {
        installStub('Dataverse metadata response exceeds the maximum size');
        const provider = new PptbMetadataProvider();
        await provider.getSchema();
        expect(provider.usesMetadataFallback).toBe(true);
    });

    it('still fails on other errors, and loads no relationships', async () => {
        installStub('Network error');
        const provider = new PptbMetadataProvider();
        await expect(provider.getSchema()).rejects.toThrow('Network error');
        expect(provider.usesMetadataFallback).toBe(false);
        await provider.getEntity('account');
        expect(relationshipCalls).toEqual([]);
    });
});
