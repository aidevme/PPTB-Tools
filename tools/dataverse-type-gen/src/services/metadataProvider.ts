/**
 * `window.dataverseAPI` adapter that produces the inputs the core needs: the table list, the CSDL
 * document, and per-entity attribute metadata (including option sets).
 *
 * Everything is cached per instance; the app creates a new instance whenever the active connection
 * changes. Metadata calls for many entities are throttled with {@link mapWithConcurrency}.
 */
import { parseCsdl, type AttributeMetadataInput, type EdmxSchema, type EntityMetadataInput, type OptionSetInput } from '../core';
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
        const schema = await this.getSchema();
        const summarize = (kind: 'action' | 'function') => (op: EdmxSchema['actions'][number]): OperationSummary => {
            const first = op.Parameters[0];
            const boundTo = op.IsBound && first ? first.Type.replace(/^Collection\((.*)\)$/, '$1').split('.').pop() : undefined;
            return { name: op.Name, kind, isBound: op.IsBound, boundTo, parameterCount: op.Parameters.length };
        };
        return [...schema.actions.map(summarize('action')), ...schema.functions.map(summarize('function'))];
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

/** Prefer the attribute's `OptionSet`; fall back to `GlobalOptionSet` when only that carries options. */
function pickOptionSet(row: RawRecord): OptionSetInput | null {
    const local = row.OptionSet as OptionSetInput | null | undefined;
    const global = row.GlobalOptionSet as OptionSetInput | null | undefined;
    if (local?.Options?.length) return local;
    if (global?.Options) return { ...global, IsGlobal: true };
    return local ?? global ?? null;
}
