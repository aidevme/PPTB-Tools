/**
 * `window.dataverseAPI` adapter that produces the inputs the core needs: the table list, the CSDL
 * document, and per-entity attribute metadata (including option sets).
 *
 * Everything is cached per instance; the app creates a new instance whenever the active connection
 * changes. Metadata calls for many entities are throttled with {@link mapWithConcurrency}.
 */
import { createMetadataSchema, labelText, parseCsdl, type AttributeMetadataInput, type EdmxComplexType, type EdmxOperation, type EdmxParameter, type EdmxSchema, type EntityMetadataInput, type ManyToManyRelationshipInput, type OneToManyRelationshipInput, type OptionSetInput } from '../core';
import type { EntitySummary, OperationSummary, TableType } from '../types';
import { mapWithConcurrency } from './concurrency';
import { queryAllPages } from './paging';
import { textOf } from './webApiRow';
import { dataverseApi as api, technicalMessage } from './errors';

/** Attribute types whose option set must be fetched separately, with their Web API cast type. */
const OPTION_SET_CASTS: Record<string, string> = {
    PicklistType: 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata',
    MultiSelectPicklistType: 'Microsoft.Dynamics.CRM.MultiSelectPicklistAttributeMetadata',
    StateType: 'Microsoft.Dynamics.CRM.StateAttributeMetadata',
    StatusType: 'Microsoft.Dynamics.CRM.StatusAttributeMetadata',
};

/** The derived attribute type whose navigation properties hold the option set; `undefined` for non-choice attributes. */
function optionSetCast(attribute: AttributeMetadataInput): string | undefined {
    const typeName = attribute.AttributeTypeName?.Value;
    return typeName ? OPTION_SET_CASTS[typeName] : undefined;
}

/** How many metadata requests run at once when loading several tables or option sets. */
export const METADATA_CONCURRENCY = 4;

type RawRecord = Record<string, unknown>;

/** A metadata label's user-localized text, via core's `labelText`. */
const label = (value: unknown): string => labelText(value as Parameters<typeof labelText>[0]);

/**
 * PPTB's `getCSDLDocument` caps the `$metadata` response at 16 MiB (its batch response limit), and large
 * environments exceed that, either compressed ("exceeds the maximum size") or once decompressed ("Cannot
 * create a Buffer larger than … bytes"). Those environments fall back to {@link createMetadataSchema}.
 */
function isCsdlSizeLimitError(error: unknown): boolean {
    const message = technicalMessage(error);
    return /larger than \d+ bytes|exceeds the maximum size/i.test(message);
}

/** Only the navigation property columns are needed from the relationship metadata. */
const ONE_TO_MANY_COLUMNS = ['SchemaName', 'ReferencedEntity', 'ReferencingEntity', 'ReferencedEntityNavigationPropertyName', 'ReferencingEntityNavigationPropertyName'];
const MANY_TO_MANY_COLUMNS = ['SchemaName', 'Entity1LogicalName', 'Entity2LogicalName', 'Entity1NavigationPropertyName', 'Entity2NavigationPropertyName'];

/**
 * Loads the Dataverse metadata the generator needs through `window.dataverseAPI`.
 * @remarks Everything is cached on the instance, so the app creates one per connection; {@link PptbMetadataProvider.reset}
 * clears the cache.
 */
export class PptbMetadataProvider {
    private entityList?: Promise<EntitySummary[]>;
    private csdl?: Promise<string>;
    private schema?: Promise<EdmxSchema>;
    /** Set once the CSDL turned out to be too large and the schema was rebuilt from metadata. */
    private metadataFallback = false;
    private readonly entityCache = new Map<string, Promise<EntityMetadataInput>>();
    private customApis?: Promise<CustomApiRecord[]>;
    /** Whether the bulk `queryData` option-set query works on this host; `undefined` until tried. */
    private bulkOptionSetsSupported?: boolean;

    /** All tables, sorted by display name. */
    listEntities(): Promise<EntitySummary[]> {
        if (!this.entityList) {
            this.entityList = api()
                .getAllEntitiesMetadata([
                    'LogicalName',
                    'SchemaName',
                    'DisplayName',
                    'Description',
                    'EntitySetName',
                    'MetadataId',
                    'IsCustomEntity',
                    'IsManaged',
                    'TableType',
                    'IsActivity',
                ])
                .then((result) =>
                    result.value
                        .map((e) => ({
                            logicalName: e.LogicalName,
                            schemaName: textOf(e, 'SchemaName') ?? e.LogicalName,
                            displayName: label(e.DisplayName) || e.LogicalName,
                            description: label(e.Description),
                            entitySetName: textOf(e, 'EntitySetName'),
                            metadataId: e.MetadataId,
                            isCustom: e.IsCustomEntity === true,
                            isManaged: e.IsManaged === true,
                            tableType: toTableType(e),
                        }))
                        .sort((a, b) => a.displayName.localeCompare(b.displayName) || a.logicalName.localeCompare(b.logicalName)),
                )
                .catch((error: unknown) => {
                    this.entityList = undefined;
                    throw error;
                });
        }
        return this.entityList;
    }

    /** Raw `$metadata` document, fetched once per connection. */
    getCsdl(): Promise<string> {
        if (!this.csdl) {
            this.csdl = api()
                .getCSDLDocument()
                .catch((error: unknown) => {
                    this.csdl = undefined;
                    throw error;
                });
        }
        return this.csdl;
    }

    /**
     * Parsed CSDL, parsed once per connection. When the CSDL is too large for PPTB, a schema rebuilt from
     * the table list instead (see {@link usesMetadataFallback}).
     */
    getSchema(): Promise<EdmxSchema> {
        if (!this.schema) {
            this.schema = this.getCsdl()
                .then((xml) => parseCsdl(xml))
                .catch(async (error: unknown) => {
                    if (!isCsdlSizeLimitError(error)) throw error;
                    console.warn('The $metadata document is too large for PPTB; rebuilding the schema from table metadata.', error);
                    const entities = await this.listEntities();
                    this.metadataFallback = true;
                    return createMetadataSchema(entities.map((e) => ({ logicalName: e.logicalName, entitySetName: e.entitySetName })));
                })
                .catch((error: unknown) => {
                    this.schema = undefined;
                    throw error;
                });
        }
        return this.schema;
    }

    /**
     * Whether the schema was rebuilt from table and relationship metadata because the `$metadata` document
     * is too large for PPTB. Built-in actions/functions and custom process actions are unavailable then.
     */
    get usesMetadataFallback(): boolean {
        return this.metadataFallback;
    }

    /** Actions and functions from the CSDL, for the Select step. */
    async listOperations(): Promise<OperationSummary[]> {
        // Without read access to `customapi` the CSDL list still works; the custom-API flags are just missing.
        const customApisOrNone = this.getCustomApis().catch((error: unknown): CustomApiRecord[] => {
            console.warn('Could not list custom APIs', error);
            return [];
        });
        const [schema, customApis, processActions] = await Promise.all([this.getSchema(), customApisOrNone, listProcessActions()]);
        const customByName = new Map(customApis.map((c) => [c.uniqueName, c]));
        const processByName = new Map(processActions.map((p) => [p.uniqueName, p]));
        const summarize = (kind: 'action' | 'function') => (op: EdmxSchema['actions'][number]): OperationSummary => {
            const first = op.Parameters[0];
            const boundTo = op.IsBound && first ? first.Type.replace(/^Collection\((.*)\)$/, '$1').split('.').pop() : undefined;
            const custom = customByName.get(op.Name);
            const process = custom ? undefined : processByName.get(op.Name);
            return {
                name: op.Name,
                kind,
                isBound: op.IsBound,
                boundTo,
                parameterCount: op.Parameters.length,
                isCustomApi: !!custom,
                isProcessAction: !!process,
                displayName: custom?.displayName ?? process?.displayName,
                componentId: custom?.id ?? process?.id,
                isPrivate: custom?.isPrivate ?? false,
                inMetadata: true,
            };
        };
        const operations = [...schema.actions.map(summarize('action')), ...schema.functions.map(summarize('function'))];

        // Custom APIs missing from $metadata (private ones) are listed so users can see why they cannot be picked.
        const listed = new Set(operations.map((o) => o.name));
        for (const custom of customApis) {
            if (listed.has(custom.uniqueName)) continue;
            operations.push({
                name: custom.uniqueName,
                kind: custom.isFunction ? 'function' : 'action',
                isBound: custom.boundEntity !== undefined,
                boundTo: custom.boundEntity,
                parameterCount: 0,
                isCustomApi: true,
                isProcessAction: false,
                isPrivate: custom.isPrivate,
                displayName: custom.displayName,
                componentId: custom.id,
                inMetadata: false,
            });
        }
        return operations;
    }

    /** Custom API records, fetched once per connection. A failed fetch isn't cached, so the next call retries. */
    getCustomApis(): Promise<CustomApiRecord[]> {
        if (!this.customApis) {
            this.customApis = listCustomApis().catch((error: unknown) => {
                this.customApis = undefined;
                throw error;
            });
        }
        return this.customApis;
    }

    /**
     * The CSDL schema plus definitions for any selected custom API that `$metadata` does not contain
     * (private custom APIs, or ones created after the environment's metadata cache was built). Those are
     * built from the `customapi` record and its request parameters.
     *
     * Throws when the custom API records can't be read, rather than generating without the selected
     * operations. A selected name that isn't a custom API in the environment (for example one deleted since
     * it was selected) is skipped with a console warning.
     */
    async getSchemaForSelection(actions: readonly string[], functions: readonly string[]): Promise<EdmxSchema> {
        const schema = await this.getSchema();
        const known = new Set([...schema.actions, ...schema.functions].map((o) => o.Name));
        const wanted = [...actions, ...functions].filter((name) => !known.has(name));
        if (wanted.length === 0) return schema;

        let customApis: CustomApiRecord[];
        try {
            customApis = await this.getCustomApis();
        } catch (error) {
            throw new Error(`Could not read the custom API definitions for ${wanted.join(', ')}: ${technicalMessage(error)}`, { cause: error });
        }
        const extraActions: EdmxOperation[] = [];
        const extraFunctions: EdmxOperation[] = [];
        const extraComplexTypes: EdmxComplexType[] = [];
        const knownComplex = new Set(schema.complexTypes.map((c) => c.Name));
        for (const name of wanted) {
            const custom = customApis.find((c) => c.uniqueName === name);
            if (!custom) {
                console.warn(`Selected operation ${name} is neither in $metadata nor a custom API in this environment; skipped.`);
                continue;
            }
            const { operation, response } = await buildCustomApiOperation(custom);
            (custom.isFunction ? extraFunctions : extraActions).push(operation);
            if (response && !knownComplex.has(response.Name)) {
                knownComplex.add(response.Name);
                extraComplexTypes.push(response);
            }
        }
        if (extraActions.length === 0 && extraFunctions.length === 0) return schema;
        const byName = <T extends { Name: string }>(a: T, b: T) => (a.Name > b.Name ? 1 : -1);
        return {
            ...schema,
            complexTypes: [...schema.complexTypes, ...extraComplexTypes].sort(byName),
            actions: [...schema.actions, ...extraActions].sort(byName),
            functions: [...schema.functions, ...extraFunctions].sort(byName),
        };
    }

    /** Entity + attributes + option sets for one table (cached). */
    getEntity(logicalName: string): Promise<EntityMetadataInput> {
        let cached = this.entityCache.get(logicalName);
        if (!cached) {
            cached = this.fetchEntity(logicalName).catch((error: unknown) => {
                this.entityCache.delete(logicalName);
                throw error;
            });
            this.entityCache.set(logicalName, cached);
        }
        return cached;
    }

    /** Fetch several entities with limited concurrency, reporting progress per finished entity. */
    getEntities(
        logicalNames: readonly string[],
        onProgress?: (completed: number, total: number, logicalName: string) => void,
    ): Promise<EntityMetadataInput[]> {
        return mapWithConcurrency(logicalNames, METADATA_CONCURRENCY, (name) => this.getEntity(name), onProgress);
    }

    /** Drop all cached data (e.g. after the user asks for a refresh). */
    reset(): void {
        this.entityList = undefined;
        this.csdl = undefined;
        this.metadataFallback = false;
        this.schema = undefined;
        this.entityCache.clear();
        this.customApis = undefined;
        this.bulkOptionSetsSupported = undefined;
    }

    private async fetchEntity(logicalName: string): Promise<EntityMetadataInput> {
        const dataverse = api();
        const [entity, attributes, relationships] = await Promise.all([
            dataverse.getEntityMetadata(logicalName, true, ['LogicalName', 'SchemaName', 'EntitySetName', 'PrimaryIdAttribute']),
            // No $select: Targets, Format and DateTimeBehavior live on derived attribute types and cannot be
            // selected on the base Attributes collection, so take everything.
            dataverse.getEntityRelatedMetadata(logicalName, 'Attributes'),
            // Navigation properties normally come from the CSDL; only the fallback schema needs these.
            this.metadataFallback ? this.fetchRelationships(logicalName) : Promise.resolve(undefined),
        ]);
        const attributeList = attributes.value as unknown as AttributeMetadataInput[];
        await this.attachOptionSets(logicalName, attributeList);
        return {
            LogicalName: entity.LogicalName,
            SchemaName: textOf(entity, 'SchemaName') ?? '',
            EntitySetName: textOf(entity, 'EntitySetName') ?? '',
            PrimaryIdAttribute: textOf(entity, 'PrimaryIdAttribute'),
            Attributes: attributeList,
            ...relationships,
        };
    }

    private async fetchRelationships(
        logicalName: string,
    ): Promise<Pick<EntityMetadataInput, 'ManyToOneRelationships' | 'OneToManyRelationships' | 'ManyToManyRelationships'>> {
        const dataverse = api();
        const [manyToOne, oneToMany, manyToMany] = await Promise.all([
            dataverse.getEntityRelatedMetadata(logicalName, 'ManyToOneRelationships', ONE_TO_MANY_COLUMNS),
            dataverse.getEntityRelatedMetadata(logicalName, 'OneToManyRelationships', ONE_TO_MANY_COLUMNS),
            dataverse.getEntityRelatedMetadata(logicalName, 'ManyToManyRelationships', MANY_TO_MANY_COLUMNS),
        ]);
        return {
            ManyToOneRelationships: manyToOne.value as unknown as OneToManyRelationshipInput[],
            OneToManyRelationships: oneToMany.value as unknown as OneToManyRelationshipInput[],
            ManyToManyRelationships: manyToMany.value as unknown as ManyToManyRelationshipInput[],
        };
    }

    /**
     * Option sets are navigation properties on the derived attribute types and are not part of the
     * plain `Attributes` listing. Try one bulk query per cast type first (4 requests per entity); if
     * the host does not accept that URL shape, fall back to one request per attribute.
     */
    private async attachOptionSets(logicalName: string, attributes: AttributeMetadataInput[]): Promise<void> {
        const needing = attributes.filter((a) => optionSetCast(a) !== undefined);
        if (needing.length === 0) return;

        if (this.bulkOptionSetsSupported !== false) {
            try {
                const byLogicalName = new Map(needing.map((a) => [a.LogicalName, a]));
                const casts = new Set(needing.map(optionSetCast).filter((cast): cast is string => cast !== undefined));
                for (const cast of casts) {
                    const query = `EntityDefinitions(LogicalName='${logicalName}')/Attributes/${cast}?$select=LogicalName&$expand=OptionSet,GlobalOptionSet`;
                    const result = await api().queryData(query);
                    for (const row of result.value) {
                        const attribute = byLogicalName.get(textOf(row, 'LogicalName') ?? '');
                        if (attribute) attribute.OptionSet = pickOptionSet(row);
                    }
                }
                this.bulkOptionSetsSupported = true;
            } catch (error) {
                if (this.bulkOptionSetsSupported === true) throw error;
                console.warn('Bulk option-set query not supported, falling back to per-attribute requests', error);
                this.bulkOptionSetsSupported = false;
            }
        }

        const missing = needing.filter((a) => !a.OptionSet?.Options);
        if (missing.length === 0) return;
        await mapWithConcurrency(missing, METADATA_CONCURRENCY, async (attribute) => {
            attribute.OptionSet = await this.fetchSingleOptionSet(logicalName, attribute);
        });
    }

    private async fetchSingleOptionSet(logicalName: string, attribute: AttributeMetadataInput): Promise<OptionSetInput> {
        const dataverse = api();
        const cast = optionSetCast(attribute);
        if (!cast) throw new Error(`${logicalName}.${attribute.LogicalName} is not a choice attribute`);
        const paths: Array<`Attributes(${string})/${string}`> = [
            `Attributes(LogicalName='${attribute.LogicalName}')/OptionSet`,
            `Attributes(LogicalName='${attribute.LogicalName}')/${cast}/OptionSet`,
            `Attributes(LogicalName='${attribute.LogicalName}')/${cast}/GlobalOptionSet`,
        ];
        let lastError: unknown;
        for (const path of paths) {
            try {
                const result = (await dataverse.getEntityRelatedMetadata(logicalName, path)) as RawRecord;
                if (Array.isArray(result.Options)) return result as unknown as OptionSetInput;
            } catch (error) {
                lastError = error;
            }
        }
        throw new Error(
            `Could not load the option set for ${logicalName}.${attribute.LogicalName}: ${technicalMessage(lastError)}`,
        );
    }
}

interface CustomApiRecord {
    id: string;
    uniqueName: string;
    displayName?: string;
    isFunction: boolean;
    isPrivate: boolean;
    /** 0 = Global, 1 = Entity, 2 = EntityCollection */
    bindingType: number;
    boundEntity?: string;
}

/**
 * Custom API records, used to flag operations as custom and to surface private ones that `$metadata`
 * leaves out. Throws on failure (e.g. no read privilege on `customapi`); callers decide whether that's fatal.
 */
async function listCustomApis(): Promise<CustomApiRecord[]> {
    // All of them, page by page: an environment can have more than one page (5,000) of custom APIs.
    const rows = await queryAllPages((query) => api().queryData(query), {
        entitySet: 'customapis',
        select: ['customapiid', 'uniquename', 'displayname', 'isfunction', 'isprivate', 'bindingtype', 'boundentitylogicalname'],
        idField: 'customapiid',
    });
    return rows.map((row) => ({
        id: textOf(row, 'customapiid') ?? '',
        uniqueName: textOf(row, 'uniquename') ?? '',
        displayName: textOf(row, 'displayname') || undefined,
        isFunction: row.isfunction === true,
        isPrivate: row.isprivate === true,
        bindingType: typeof row.bindingtype === 'number' ? row.bindingtype : 0,
        // bindingtype: 0 = Global, 1 = Entity, 2 = EntityCollection
        boundEntity: row.bindingtype === 0 ? undefined : textOf(row, 'boundentitylogicalname'),
    }));
}

/**
 * Custom API request parameter `type` option values mapped to the EDM type `$metadata` would publish.
 * `mscrm.crmbaseentity` is used when no table is specified (the generator maps it to `any`).
 */
function customApiParameterType(type: number, logicalEntityName: string | null | undefined): string {
    const entity = logicalEntityName ? `mscrm.${logicalEntityName}` : 'mscrm.crmbaseentity';
    switch (type) {
        case 0:
            return 'Edm.Boolean';
        case 1:
            return 'Edm.DateTimeOffset';
        case 2: // Decimal
        case 8: // Money
            return 'Edm.Decimal';
        case 3: // Entity
        case 5: // EntityReference
            return entity;
        case 4: // EntityCollection
            return `Collection(${entity})`;
        case 6:
            return 'Edm.Double';
        case 7: // Integer
        case 9: // Picklist
            return 'Edm.Int32';
        case 11:
            return 'Collection(Edm.String)';
        case 12:
            return 'Edm.Guid';
        case 10:
        default:
            return 'Edm.String';
    }
}

/**
 * Build an operation definition from a `customapi` record and its request parameters, plus the
 * `<UniqueName>Response` complex type `$metadata` would publish for its response properties (none when
 * the custom API has no response properties).
 */
async function buildCustomApiOperation(custom: CustomApiRecord): Promise<{ operation: EdmxOperation; response?: EdmxComplexType }> {
    const [requestResult, responseResult] = await Promise.all([
        api().queryData(`customapirequestparameters?$select=uniquename,type,isoptional,logicalentityname&$filter=_customapiid_value eq ${custom.id}`),
        api().queryData(`customapiresponseproperties?$select=uniquename,type,logicalentityname&$filter=_customapiid_value eq ${custom.id}`),
    ]);
    const parameters: EdmxParameter[] = [];
    const bound = custom.bindingType !== 0 && !!custom.boundEntity;
    if (bound) {
        // $metadata names the binding parameter `entity` (single record) or `entityset` (collection).
        const collection = custom.bindingType === 2;
        parameters.push({
            Name: collection ? 'entityset' : 'entity',
            Type: collection ? `Collection(mscrm.${custom.boundEntity})` : `mscrm.${custom.boundEntity}`,
            Nullable: false,
        });
    }
    const requestParameters = requestResult.value
        .map((row) => ({
            Name: textOf(row, 'uniquename') ?? '',
            Type: customApiParameterType(Number(row.type), textOf(row, 'logicalentityname')),
            Nullable: row.isoptional === true,
        }))
        .sort((a, b) => a.Name.localeCompare(b.Name));
    parameters.push(...requestParameters);

    const operation: EdmxOperation = { Name: custom.uniqueName, IsBound: bound, ReturnsCollection: false, Parameters: parameters };
    if (responseResult.value.length === 0) return { operation };
    const response: EdmxComplexType = {
        Name: `${custom.uniqueName}Response`,
        // Sorted like the CSDL parser's `readProperties`.
        Properties: responseResult.value
            .map((row) => ({
                Name: textOf(row, 'uniquename') ?? '',
                Type: customApiParameterType(Number(row.type), textOf(row, 'logicalentityname')),
                Nullable: true,
            }))
            .sort((a, b) => (a.Name > b.Name ? 1 : -1)),
        NavigationProperties: [],
    };
    operation.ReturnType = `mscrm.${response.Name}`;
    return { operation, response };
}

interface ProcessActionRecord {
    id: string;
    /** Message name of the action (the workflow's unique name, e.g. `new_DoSomething`). */
    uniqueName: string;
    displayName?: string;
}

/**
 * Classic custom process actions (workflow category 3, definition rows only). Their message name is the
 * workflow's unique name. Failure is not fatal.
 */
async function listProcessActions(): Promise<ProcessActionRecord[]> {
    try {
        // All of them, page by page, like the custom APIs.
        const rows = await queryAllPages((query) => api().queryData(query), {
            entitySet: 'workflows',
            select: ['workflowid', 'uniquename', 'name'],
            idField: 'workflowid',
            filter: 'category eq 3 and type eq 1',
        });
        return rows
            .filter((row) => typeof row.uniquename === 'string' && row.uniquename)
            .map((row) => ({
                id: textOf(row, 'workflowid') ?? '',
                uniqueName: textOf(row, 'uniquename') ?? '',
                displayName: textOf(row, 'name') || undefined,
            }));
    } catch (error) {
        console.warn('Could not list custom process actions', error);
        return [];
    }
}

/** Prefer the attribute's `OptionSet`; fall back to `GlobalOptionSet` when only that carries options. */
function pickOptionSet(row: RawRecord): OptionSetInput | null {
    const local = row.OptionSet as OptionSetInput | null | undefined;
    const global = row.GlobalOptionSet as OptionSetInput | null | undefined;
    if (local?.Options?.length) return local;
    if (global?.Options) return { ...global, IsGlobal: true };
    return local ?? global ?? null;
}

/**
 * A table's type from its metadata: Elastic or Virtual from `TableType`, Activity from `IsActivity` (activity
 * tables report `TableType: 'Standard'`), and Standard otherwise, including when `TableType` is missing.
 */
export function toTableType(metadata: object): TableType {
    // PPTB's EntityMetadata type doesn't declare these, though the Web API returns them when selected.
    const { TableType: tableType, IsActivity: isActivity } = metadata as { TableType?: unknown; IsActivity?: unknown };
    if (tableType === 'Elastic') return 'Elastic';
    if (tableType === 'Virtual') return 'Virtual';
    if (isActivity === true) return 'Activity';
    return 'Standard';
}
