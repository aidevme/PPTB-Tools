/**
 * Fallback for environments whose `$metadata` (CSDL) document cannot be loaded, for example because it is
 * larger than the 16 MiB PPTB allows for `getCSDLDocument`.
 *
 * The generator only needs a few things from the CSDL for tables: every entity's name, and for the
 * selected ones their key, entity set and navigation properties. Properties already come from attribute
 * metadata. All of that can be rebuilt from `EntityDefinitions` and the relationship metadata, which is
 * what the Web API itself derives the CSDL navigation properties from:
 *
 * - many-to-one: `ReferencingEntityNavigationPropertyName` → single-valued, typed as the referenced entity
 * - one-to-many: `ReferencedEntityNavigationPropertyName` → collection of the referencing entity
 * - many-to-many: `Entity1/2NavigationPropertyName` → collection of the other entity
 *
 * Actions, functions, complex types and enums have no metadata equivalent, so the fallback schema has
 * none; custom APIs are added from their records by the metadata provider.
 */
import type { EdmxEntityType, EdmxNavigationProperty, EdmxSchema, EntityMetadataInput } from './types';

/**
 * Entities the CSDL declares under a different name than the relationship metadata uses. Owner lookups
 * reference the `owner` entity, but the CSDL types those navigation properties as the abstract
 * `mscrm.principal` (the base of `systemuser` and `team`).
 */
const CSDL_ENTITY_NAMES: Record<string, string> = { owner: 'principal' };

/** Abstract CSDL entity types that have no `EntityDefinitions` row of their own. */
const ABSTRACT_ENTITY_TYPES = ['crmbaseentity', 'principal'];

/** Minimal table description needed to stand in for a CSDL `<EntityType>`. */
export interface EntityTypeSource {
    logicalName: string;
    entitySetName?: string;
}

/**
 * An {@link EdmxSchema} with one entity type per table and no actions, functions, complex types or
 * enums. Navigation properties are left empty; `buildSchemaModel` derives them per entity with
 * {@link navigationFromRelationships}.
 */
export function createMetadataSchema(entities: readonly EntityTypeSource[]): EdmxSchema {
    const entityTypes: EdmxEntityType[] = entities.map((e) => ({
        Name: e.logicalName,
        BaseType: 'mscrm.crmbaseentity',
        Abstract: false,
        EntitySetName: e.entitySetName,
        Properties: [],
        NavigationProperties: [],
    }));
    const known = new Set(entityTypes.map((e) => e.Name));
    for (const name of ABSTRACT_ENTITY_TYPES) {
        if (!known.has(name)) entityTypes.push({ Name: name, Abstract: true, Properties: [], NavigationProperties: [] });
    }
    return {
        source: 'metadata',
        entityTypes: entityTypes.sort((a, b) => (a.Name > b.Name ? 1 : -1)),
        complexTypes: [],
        enumTypes: [],
        actions: [],
        functions: [],
    };
}

function navigation(name: string | null | undefined, targetEntity: string, isCollection: boolean): EdmxNavigationProperty | undefined {
    if (!name) return undefined;
    const logicalName = CSDL_ENTITY_NAMES[targetEntity] ?? targetEntity;
    return { Name: name, FullName: name, Type: `mscrm.${logicalName}`, IsCollection: isCollection, LogicalName: logicalName };
}

/**
 * The navigation properties the CSDL would declare on `metadata`'s entity type, rebuilt from its
 * relationship metadata. Sorted by name like the CSDL parser's output; duplicates are dropped.
 */
export function navigationFromRelationships(metadata: EntityMetadataInput): EdmxNavigationProperty[] {
    const self = metadata.LogicalName;
    const result: Array<EdmxNavigationProperty | undefined> = [];
    for (const r of metadata.ManyToOneRelationships ?? []) {
        if (r.ReferencingEntity === self) result.push(navigation(r.ReferencingEntityNavigationPropertyName, r.ReferencedEntity, false));
    }
    for (const r of metadata.OneToManyRelationships ?? []) {
        if (r.ReferencedEntity === self) result.push(navigation(r.ReferencedEntityNavigationPropertyName, r.ReferencingEntity, true));
    }
    for (const r of metadata.ManyToManyRelationships ?? []) {
        if (r.Entity1LogicalName === self) result.push(navigation(r.Entity1NavigationPropertyName, r.Entity2LogicalName, true));
        if (r.Entity2LogicalName === self) result.push(navigation(r.Entity2NavigationPropertyName, r.Entity1LogicalName, true));
    }
    const byName = new Map<string, EdmxNavigationProperty>();
    for (const n of result) if (n && !byName.has(n.Name)) byName.set(n.Name, n);
    return Array.from(byName.values()).sort((a, b) => (a.Name > b.Name ? 1 : -1));
}
