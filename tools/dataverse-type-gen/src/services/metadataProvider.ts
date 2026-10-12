/**
 * `window.dataverseAPI` adapter that produces the inputs the core needs: the table list, the CSDL
 * document, and per-entity attribute metadata (including option sets).
 *
 * Everything is cached per instance; the app creates a new instance whenever the active connection
 * changes. Metadata calls for many entities are throttled with {@link mapWithConcurrency}.
 */
import { parseCsdl, type AttributeMetadataInput, type EdmxOperation, type EdmxParameter, type EdmxSchema, type EntityMetadataInput, type OptionSetInput } from '../core';
import type { EntitySummary, OperationSummary } from '../types';
import { mapWithConcurrency } from './concurrency';

/** Attribute types whose option set must be fetched separately, with their Web API cast type. */
const OPTION_SET_CASTS: Record<string, string> = {
    PicklistType: 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata',
    MultiSelectPicklistType: 'Microsoft.Dynamics.CRM.MultiSelectPicklistAttributeMetadata',
    StateType: 'Microsoft.Dynamics.CRM.StateAttributeMetadata',
    StatusType: 'Microsoft.Dynamics.CRM.StatusAttributeMetadata',
};

export const METADATA_CONCURRENCY = 4;

type RawRecord = Record<string, unknown>;

function label(value: unknown): string {
    const l = value as { UserLocalizedLabel?: { Label?: string } | null } | null | undefined;
    return l?.UserLocalizedLabel?.Label ?? '';
}

function api(): typeof window.dataverseAPI {
    if (!window.dataverseAPI) throw new Error('The PPTB Dataverse API is not available (not running inside Power Platform ToolBox?)');
    return window.dataverseAPI;
}

export class PptbMetadataProvider {
    private entityList?: Promise<EntitySummary[]>;
    private csdl?: Promise<string>;
    private schema?: Promise<EdmxSchema>;
    private readonly entityCache = new Map<string, Promise<EntityMetadataInput>>();
    private customApis?: Promise<CustomApiRecord[]>;
    /** Whether the bulk `queryData` option-set query works on this host; `undefined` until tried. */
    private bulkOptionSetsSupported?: boolean;

    /** All tables, sorted by display name. */
    listEntities(): Promise<EntitySummary[]> {
        if (!this.entityList) {
            this.entityList = api()
                .getAllEntitiesMetadata(['LogicalName', 'SchemaName', 'DisplayName', 'EntitySetName', 'MetadataId', 'IsCustomEntity', 'IsManaged'])
                .then((result) =>
                    result.value
                        .map((e) => ({
                            logicalName: e.LogicalName,
                            schemaName: (e.SchemaName as string) ?? e.LogicalName,
                            displayName: label(e.DisplayName) || e.LogicalName,
                            entitySetName: (e.EntitySetName as string | null) ?? undefined,
                            metadataId: e.MetadataId,
                            isCustom: e.IsCustomEntity === true,
                            isManaged: e.IsManaged === true,
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

    /** Parsed CSDL, parsed once per connection. */
    getSchema(): Promise<EdmxSchema> {
        if (!this.schema) {
            this.schema = this.getCsdl()
                .then((xml) => parseCsdl(xml))
                .catch((error: unknown) => {
                    this.schema = undefined;
                    throw error;
                });
        }
        return this.schema;
    }

    /** Actions and functions from the CSDL, for the Select step. */
    async listOperations(): Promise<OperationSummary[]> {
        const [schema, customApis, processActions] = await Promise.all([this.getSchema(), this.getCustomApis(), listProcessActions()]);
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

    /** Custom API records, fetched once per connection. */
    getCustomApis(): Promise<CustomApiRecord[]> {
        if (!this.customApis) this.customApis = listCustomApis();
        return this.customApis;
    }

    /**
     * The CSDL schema plus definitions for any selected custom API that `$metadata` does not contain
     * (private custom APIs, or ones created after the environment's metadata cache was built). Those are
     * built from the `customapi` record and its request parameters.
     */
    async getSchemaForSelection(actions: readonly string[], functions: readonly string[]): Promise<EdmxSchema> {
        const schema = await this.getSchema();
        const known = new Set([...schema.actions, ...schema.functions].map((o) => o.Name));
        const wanted = [...actions, ...functions].filter((name) => !known.has(name));
        if (wanted.length === 0) return schema;

        const customApis = await this.getCustomApis();
        const extraActions: EdmxOperation[] = [];
        const extraFunctions: EdmxOperation[] = [];
        for (const name of wanted) {
            const custom = customApis.find((c) => c.uniqueName === name);
            if (!custom) continue;
            const operation = await buildCustomApiOperation(custom);
            (custom.isFunction ? extraFunctions : extraActions).push(operation);
        }
        if (extraActions.length === 0 && extraFunctions.length === 0) return schema;
        const byName = (a: EdmxOperation, b: EdmxOperation) => (a.Name > b.Name ? 1 : -1);
        return {
            ...schema,
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
        this.schema = undefined;
        this.entityCache.clear();
        this.customApis = undefined;
        this.bulkOptionSetsSupported = undefined;
    }

    private async fetchEntity(logicalName: string): Promise<EntityMetadataInput> {
        const dataverse = api();
        const [entity, attributes] = await Promise.all([
            dataverse.getEntityMetadata(logicalName, true, ['LogicalName', 'SchemaName', 'EntitySetName', 'PrimaryIdAttribute']),
            // No $select: Targets, Format and DateTimeBehavior live on derived attribute types and cannot be
            // selected on the base Attributes collection, so take everything.
            dataverse.getEntityRelatedMetadata(logicalName, 'Attributes'),
        ]);
        const attributeList = attributes.value as unknown as AttributeMetadataInput[];
        await this.attachOptionSets(logicalName, attributeList);
        return {
            LogicalName: entity.LogicalName,
            SchemaName: entity.SchemaName as string,
            EntitySetName: entity.EntitySetName as string,
            PrimaryIdAttribute: (entity.PrimaryIdAttribute as string | undefined) ?? undefined,
            Attributes: attributeList,
        };
    }

    /**
     * Option sets are navigation properties on the derived attribute types and are not part of the
     * plain `Attributes` listing. Try one bulk query per cast type first (4 requests per entity); if
     * the host does not accept that URL shape, fall back to one request per attribute.
     */
    private async attachOptionSets(logicalName: string, attributes: AttributeMetadataInput[]): Promise<void> {
        const needing = attributes.filter((a) => a.AttributeTypeName?.Value && OPTION_SET_CASTS[a.AttributeTypeName.Value]);
        if (needing.length === 0) return;

        if (this.bulkOptionSetsSupported !== false) {
            try {
                const byLogicalName = new Map(needing.map((a) => [a.LogicalName, a]));
                const casts = new Set(needing.map((a) => OPTION_SET_CASTS[a.AttributeTypeName!.Value]));
                for (const cast of casts) {
                    const query = `EntityDefinitions(LogicalName='${logicalName}')/Attributes/${cast}?$select=LogicalName&$expand=OptionSet,GlobalOptionSet`;
                    const result = await api().queryData(query);
                    for (const row of result.value) {
                        const attribute = byLogicalName.get(row.LogicalName as string);
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
        const cast = OPTION_SET_CASTS[attribute.AttributeTypeName!.Value];
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
            `Could not load the option set for ${logicalName}.${attribute.LogicalName}: ${lastError instanceof Error ? lastError.message : String(lastError)}`,
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
 * leaves out. Failure (e.g. no read privilege on `customapi`) is not fatal: the CSDL list still works.
 */
async function listCustomApis(): Promise<CustomApiRecord[]> {
    try {
        const result = await api().queryData('customapis?$select=customapiid,uniquename,displayname,isfunction,isprivate,bindingtype,boundentitylogicalname');
        return result.value.map((row) => ({
            id: row.customapiid as string,
            uniqueName: row.uniquename as string,
            displayName: (row.displayname as string | null) || undefined,
            isFunction: row.isfunction === true,
            isPrivate: row.isprivate === true,
            bindingType: typeof row.bindingtype === 'number' ? row.bindingtype : 0,
            // bindingtype: 0 = Global, 1 = Entity, 2 = EntityCollection
            boundEntity: row.bindingtype === 0 ? undefined : ((row.boundentitylogicalname as string | null) ?? undefined),
        }));
    } catch (error) {
        console.warn('Could not list custom APIs', error);
        return [];
    }
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

/** Build an operation definition from a `customapi` record and its request parameters. */
async function buildCustomApiOperation(custom: CustomApiRecord): Promise<EdmxOperation> {
    const result = await api().queryData(
        `customapirequestparameters?$select=uniquename,type,isoptional,logicalentityname&$filter=_customapiid_value eq ${custom.id}`,
    );
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
    const requestParameters = result.value
        .map((row) => ({
            Name: row.uniquename as string,
            Type: customApiParameterType(Number(row.type), row.logicalentityname as string | null),
            Nullable: row.isoptional === true,
        }))
        .sort((a, b) => a.Name.localeCompare(b.Name));
    parameters.push(...requestParameters);
    return { Name: custom.uniqueName, IsBound: bound, ReturnsCollection: false, Parameters: parameters };
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
        const result = await api().queryData('workflows?$select=workflowid,uniquename,name&$filter=category eq 3 and type eq 1');
        return result.value
            .filter((row) => typeof row.uniquename === 'string' && row.uniquename)
            .map((row) => ({
                id: row.workflowid as string,
                uniqueName: row.uniquename as string,
                displayName: (row.name as string | null) || undefined,
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
