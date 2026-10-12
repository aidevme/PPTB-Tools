/**
 * Shared model types for the I/O-free generator core.
 *
 * Naming follows Scott Durow's `dataverse-gen` (`EdmxTypes.ts` / `SchemaModel.ts`) where the concept is
 * the same, so the two code bases can be compared side by side. PascalCase property names mirror the
 * EDMX / Dataverse metadata they are read from.
 */

// ---------------------------------------------------------------------------------------------------
// EDMX (CSDL $metadata document)
// ---------------------------------------------------------------------------------------------------

/** A `<Property>` of an EntityType, ComplexType, Action or Function in the CSDL. */
export interface EdmxProperty {
    Name: string;
    /** Raw EDM type, e.g. `Edm.String`, `mscrm.Label`, `Collection(mscrm.LocalizedLabel)`. */
    Type: string;
    Nullable?: boolean;
}

/** A `<NavigationProperty>` in the CSDL. */
export interface EdmxNavigationProperty {
    /** Name used in generated code (last segment of {@link EdmxNavigationProperty.FullName}). */
    Name: string;
    /** Name as declared in the CSDL. */
    FullName: string;
    /** Target type without the `Collection(...)` wrapper, e.g. `mscrm.systemuser`. */
    Type: string;
    IsCollection: boolean;
    /** Logical name of the target entity (last segment of {@link EdmxNavigationProperty.Type}). */
    LogicalName: string;
}

/** An `<EntityType>` in the CSDL. */
export interface EdmxEntityType {
    Name: string;
    BaseType?: string;
    Abstract: boolean;
    /** `Key/PropertyRef@Name` — the primary id attribute. */
    KeyName?: string;
    /** Resolved from the EntityContainer's `<EntitySet>` elements. */
    EntitySetName?: string;
    Properties: EdmxProperty[];
    NavigationProperties: EdmxNavigationProperty[];
}

/** A `<ComplexType>` in the CSDL. */
export interface EdmxComplexType {
    Name: string;
    Properties: EdmxProperty[];
    NavigationProperties: EdmxNavigationProperty[];
}

export interface EdmxEnumMember {
    Name: string;
    Value: string;
}

/** An `<EnumType>` in the CSDL. */
export interface EdmxEnumType {
    Name: string;
    Members: EdmxEnumMember[];
}

/** A `<Parameter>` of an Action or Function. */
export interface EdmxParameter {
    Name: string;
    Type: string;
    Nullable: boolean;
}

/** An `<Action>` or `<Function>` in the CSDL. */
export interface EdmxOperation {
    Name: string;
    IsBound: boolean;
    /** Return type without the `Collection(...)` wrapper. */
    ReturnType?: string;
    ReturnsCollection: boolean;
    Parameters: EdmxParameter[];
}

/** Parsed `$metadata` document, limited to what the generator needs. */
export interface EdmxSchema {
    entityTypes: EdmxEntityType[];
    complexTypes: EdmxComplexType[];
    enumTypes: EdmxEnumType[];
    actions: EdmxOperation[];
    functions: EdmxOperation[];
}

// ---------------------------------------------------------------------------------------------------
// Dataverse entity metadata (Web API `EntityDefinitions` shape)
// ---------------------------------------------------------------------------------------------------

export interface LocalizedLabelInput {
    Label?: string | null;
    LanguageCode?: number;
}

export interface LabelInput {
    UserLocalizedLabel?: LocalizedLabelInput | null;
    LocalizedLabels?: LocalizedLabelInput[];
}

export interface OptionInput {
    Value: number;
    Label?: LabelInput | null;
}

export interface OptionSetInput {
    Name: string;
    IsGlobal?: boolean;
    OptionSetType?: string;
    Options: OptionInput[];
}

/**
 * One attribute as returned by `EntityDefinitions(LogicalName='x')/Attributes` (plus `OptionSet` for
 * choice-type attributes). The same shape is produced by `RetrieveMetadataChanges`, which is what
 * `dataverse-gen` reads, so its test fixtures can be fed straight into this generator.
 */
export interface AttributeMetadataInput {
    LogicalName: string;
    SchemaName: string;
    AttributeType?: string;
    AttributeTypeName?: { Value: string } | null;
    RequiredLevel?: { Value: string } | null;
    /** 0 = simple, 1 = calculated, 2 = rollup; `null` for lookups and virtual attributes. */
    SourceType?: number | null;
    IsLogical?: boolean;
    AttributeOf?: string | null;
    /** Lookup / Customer / Owner targets. */
    Targets?: string[];
    Description?: LabelInput | null;
    DisplayName?: LabelInput | null;
    DateTimeBehavior?: { Value: string } | null;
    Format?: string | null;
    OptionSet?: OptionSetInput | null;
}

/** Entity metadata needed by the generator, independent of how it was fetched. */
export interface EntityMetadataInput {
    LogicalName: string;
    SchemaName: string;
    EntitySetName: string;
    PrimaryIdAttribute?: string;
    Attributes: AttributeMetadataInput[];
}

// ---------------------------------------------------------------------------------------------------
// Schema model: EDMX + Dataverse metadata, filtered and mapped to TypeScript types
// ---------------------------------------------------------------------------------------------------

export type OutputTypeKind = 'enum' | 'entity' | 'complex' | 'primitive';

/** Mirrors `TypeScriptType` in dataverse-gen. */
export interface TsType {
    name: string;
    outputType: OutputTypeKind;
    /** Module specifier for an `import("...")` type reference, or `undefined` for built-ins. */
    importLocation?: string;
    /** `Xrm.Attributes.*Attribute` for the form-context template; `undefined` when unknown. */
    definitelyTypedAttributeType?: string;
    /** `Xrm.Controls.*Control` for the form-context template; `undefined` when unknown. */
    definitelyTypedControlType?: string;
}

export interface EntityPropertyModel {
    /** Logical name. */
    Name: string;
    SchemaName: string;
    /** `AttributeTypeName.Value` (e.g. `StringType`), or the enum name for choice attributes. */
    Type: string;
    IsRequired: boolean;
    IsEnum: boolean;
    IsMultiSelect: boolean;
    Description: string;
    DisplayName: string;
    /** `Format:DateTimeBehavior` for date attributes, otherwise empty. */
    Format: string;
    AttributeOf?: string | null;
    SourceType?: number | null;
    TypescriptType: TsType;
}

export interface NavigationModel {
    Name: string;
    /** Comma-separated target type list, e.g. `mscrm.systemuser` or `systemuser,team`. */
    Type: string;
    IsCollection: boolean;
}

export interface EntityModel {
    /** Logical name. */
    Name: string;
    SchemaName: string;
    EntitySetName: string;
    /** Primary id attribute. */
    KeyName: string;
    Properties: EntityPropertyModel[];
    NavigationProperties: NavigationModel[];
}

export interface EnumMemberModel {
    Name: string;
    Value: string;
}

export interface EnumModel {
    Name: string;
    Members: EnumMemberModel[];
    /** CSDL enums emit `Name = "Name"`; Dataverse option sets emit `Name = value`. */
    StringMembers: boolean;
}

export interface TypedMemberModel {
    Name: string;
    TypescriptType: TsType;
}

export interface ComplexTypeModel {
    Name: string;
    Properties: TypedMemberModel[];
    NavigationProperties: TypedMemberModel[];
}

export interface ParameterModel {
    Name: string;
    Type: string;
    /** `StructuralProperty` member name used in the generated `parameterTypes`. */
    structuralTypeName: string;
    TypescriptTypes: TsType[];
}

export interface OperationModel {
    Name: string;
    IsBound: boolean;
    Parameters: ParameterModel[];
}

export interface SchemaModel {
    entities: EntityModel[];
    enums: EnumModel[];
    complexTypes: ComplexTypeModel[];
    actions: OperationModel[];
    functions: OperationModel[];
}

// ---------------------------------------------------------------------------------------------------
// Generator output
// ---------------------------------------------------------------------------------------------------

export interface GeneratedFile {
    /** Path relative to `output.outputRoot`, always forward-slash separated. */
    path: string;
    content: string;
}
