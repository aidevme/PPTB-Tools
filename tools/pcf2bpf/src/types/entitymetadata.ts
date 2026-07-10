/** A single option (key/label pair) of a choice (Picklist/MultiSelectPicklist) attribute's OptionSet. */
export interface EntityAttributeOption {
    value: number;
    label: string;
}

/** Dataverse attribute metadata for a single field on an entity, as loaded by {@link loadEntityMetadata}. */
export interface EntityAttributeMetadata {
    logicalName: string;
    displayName: string;
    attributeType: string;
    /** `RequiredLevel.Value`, e.g. "None", "SystemRequired", "ApplicationRequired", "Recommended". */
    requiredLevel: string;
    metadataId: string;
    description: string;
    /** Choice values (key/label), populated only for Picklist/MultiSelectPicklist attributes. */
    options?: EntityAttributeOption[];
}

/** Dataverse entity metadata plus its full attribute list, as loaded by {@link loadEntityMetadata}. */
export interface EntityMetadataInfo {
    logicalName: string;
    displayName: string;
    objectTypeCode: number;
    metadataId: string;
    description: string;
    attributes: EntityAttributeMetadata[];
}

