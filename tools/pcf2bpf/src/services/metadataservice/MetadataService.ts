import type { EntityAttributeMetadata, EntityAttributeOption, EntityMetadataInfo } from "../../types";

function api(): typeof window.dataverseAPI {
    return window.dataverseAPI;
}

function labelText(label: any, fallback: string): string {
    return label?.UserLocalizedLabel?.Label ?? label?.LocalizedLabels?.[0]?.Label ?? fallback;
}

/**
 * Choice attribute types whose OptionSet values {@link loadEntityMetadata} resolves, mapped to the Web
 * API type-cast segment needed to reach their `OptionSet` navigation property — the base `Attributes`
 * collection's `AttributeMetadata` type doesn't expose `OptionSet` itself; only these derived types do,
 * and Dataverse's Web API returns a "Resource not found for the segment 'OptionSet'" error without the cast.
 */
const OPTIONSET_CAST_BY_ATTRIBUTE_TYPE: Record<string, string> = {
    Picklist: "Microsoft.Dynamics.CRM.PicklistAttributeMetadata",
    MultiSelectPicklist: "Microsoft.Dynamics.CRM.MultiSelectPicklistAttributeMetadata",
};

/** Loads a choice attribute's OptionSet as key/label pairs. */
async function loadOptionSetValues(
    entityLogicalName: string,
    attributeLogicalName: string,
    attributeType: string,
): Promise<EntityAttributeOption[]> {
    const cast = OPTIONSET_CAST_BY_ATTRIBUTE_TYPE[attributeType];
    if (!cast) return [];

    const optionSet = await api().getEntityRelatedMetadata(
        entityLogicalName,
        `Attributes(LogicalName='${attributeLogicalName}')/${cast}/OptionSet`,
    );
    const options = (optionSet as any)?.Options as Array<Record<string, any>> | undefined;
    if (!Array.isArray(options)) return [];

    return options.map((option) => ({
        value: Number(option.Value),
        label: labelText(option.Label, String(option.Value)),
    }));
}

/**
 * Loads a specified entity's metadata (LogicalName, DisplayName, ObjectTypeCode, MetadataId,
 * Description) together with its full attribute list (LogicalName, DisplayName, AttributeType,
 * RequiredLevel, MetadataId, Description per attribute). Picklist/MultiSelectPicklist attributes also
 * get their OptionSet's key/label pairs resolved into `options` (one extra call per choice attribute).
 *
 * @throws If the entity's `ObjectTypeCode` can't be resolved via entity metadata.
 */
export async function loadEntityMetadata(entityLogicalName: string): Promise<EntityMetadataInfo> {
    const [entity, attributesResponse] = await Promise.all([
        api().getEntityMetadata(entityLogicalName, true, ["LogicalName", "DisplayName", "ObjectTypeCode", "MetadataId", "Description"]),
        api().getEntityRelatedMetadata(entityLogicalName, "Attributes", [
            "LogicalName",
            "DisplayName",
            "AttributeType",
            "RequiredLevel",
            "MetadataId",
            "Description",
        ]),
    ]);

    const objectTypeCode = (entity as any).ObjectTypeCode;
    if (objectTypeCode === undefined || objectTypeCode === null) {
        throw new Error(`Could not resolve the object type code for "${entityLogicalName}".`);
    }

    const attributes = await Promise.all(
        (attributesResponse.value as Array<Record<string, any>>)
            .filter((a) => a.AttributeType)
            .map(async (a): Promise<EntityAttributeMetadata> => {
                const attributeType = a.AttributeType as string;
                const options = OPTIONSET_CAST_BY_ATTRIBUTE_TYPE[attributeType]
                    ? await loadOptionSetValues(entityLogicalName, a.LogicalName, attributeType)
                    : undefined;

                return {
                    logicalName: a.LogicalName,
                    displayName: labelText(a.DisplayName, a.LogicalName),
                    attributeType,
                    requiredLevel: a.RequiredLevel?.Value ?? "None",
                    metadataId: a.MetadataId,
                    description: labelText(a.Description, ""),
                    options,
                };
            }),
    );

    return {
        logicalName: entity.LogicalName ?? entityLogicalName,
        displayName: labelText(entity.DisplayName, entityLogicalName),
        objectTypeCode: Number(objectTypeCode),
        metadataId: entity.MetadataId,
        description: labelText((entity as any).Description, ""),
        attributes,
    };
}
