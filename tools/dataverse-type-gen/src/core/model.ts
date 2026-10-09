/**
 * Builds the {@link SchemaModel} the templates render from: the CSDL schema filtered down to the
 * configured selection, enriched with Dataverse attribute metadata, and mapped to TypeScript types.
 *
 * This is a port of `SchemaModel.ts` from Scott Durow's `dataverse-gen`, kept deliberately close to the
 * original so the generated output stays byte-compatible (see `test/generator.test.ts`). Deviations
 * that fix output which would not compile are marked with `// Deviation:`.
 */
import type { ResolvedConfig } from './config';
import { isCollectionType, shortTypeName, stripCollection } from './csdl';
import type {
    AttributeMetadataInput,
    ComplexTypeModel,
    EdmxComplexType,
    EdmxEntityType,
    EdmxEnumType,
    EdmxOperation,
    EdmxParameter,
    EdmxSchema,
    EntityMetadataInput,
    EntityModel,
    EntityPropertyModel,
    EnumModel,
    NavigationModel,
    OperationModel,
    OptionSetInput,
    OutputTypeKind,
    ParameterModel,
    SchemaModel,
    TsType,
} from './types';

/** The subset of the CSDL that the configured selection pulls in. */
export interface Selection {
    entities: EdmxEntityType[];
    actions: EdmxOperation[];
    functions: EdmxOperation[];
    complexTypes: EdmxComplexType[];
    enumTypes: EdmxEnumType[];
}

type StructuralProperty = 'Unknown' | 'PrimitiveType' | 'ComplexType' | 'EnumerationType' | 'Collection' | 'EntityType';

const byName = <T extends { Name: string }>(a: T, b: T) => (a.Name > b.Name ? 1 : -1);

/**
 * Work out which CSDL types the selection needs. Entities referenced by a selected action or function
 * (for example `opportunityclose` for `WinOpportunity`) are included even when not selected
 * themselves, exactly like dataverse-gen; complex types and enums are included transitively.
 *
 * Callers use `selection.entities` to know which entities' metadata must be fetched before calling
 * {@link buildSchemaModel}.
 */
export function resolveSelection(edmx: EdmxSchema, config: ResolvedConfig): Selection {
    const entityIndex = new Map(edmx.entityTypes.map((e) => [e.Name, e]));
    const complexIndex = new Map(edmx.complexTypes.map((c) => [c.Name, c]));
    const enumIndex = new Map(edmx.enumTypes.map((e) => [e.Name, e]));

    const actionNames = new Set(config.actions);
    const functionNames = new Set(config.functions);
    const actions = edmx.actions.filter((a) => actionNames.has(a.Name));
    const functions = edmx.functions.filter((f) => functionNames.has(f.Name));

    const referencedEntities = new Set<string>();
    const referencedComplex = new Set<string>();
    const referencedEnums = new Set<string>();

    const reference = (type: string | undefined) => {
        if (!type) return;
        const name = shortTypeName(type);
        if (complexIndex.has(name)) referencedComplex.add(name);
        else if (entityIndex.has(name)) referencedEntities.add(name);
        else if (enumIndex.has(name)) referencedEnums.add(name);
    };
    for (const operation of [...actions, ...functions]) {
        for (const parameter of operation.Parameters) reference(parameter.Type);
        reference(operation.ReturnType);
    }

    // Complex types referenced by other complex types, recursively (dataverse-gen only follows
    // `Properties`, not `NavigationProperties`).
    const visitComplex = (complexType: EdmxComplexType) => {
        for (const property of complexType.Properties) {
            const name = shortTypeName(property.Type);
            const nested = complexIndex.get(name);
            if (nested) {
                if (!referencedComplex.has(name)) {
                    referencedComplex.add(name);
                    visitComplex(nested);
                }
            } else if (enumIndex.has(name)) {
                referencedEnums.add(name);
            }
        }
    };
    for (const name of Array.from(referencedComplex)) {
        const complexType = complexIndex.get(name);
        if (complexType) visitComplex(complexType);
    }

    const selectedEntities = new Set(config.entities);
    return {
        entities: edmx.entityTypes.filter((e) => selectedEntities.has(e.Name) || referencedEntities.has(e.Name)),
        actions,
        functions,
        complexTypes: edmx.complexTypes.filter((c) => referencedComplex.has(c.Name)),
        enumTypes: edmx.enumTypes.filter((e) => referencedEnums.has(e.Name)),
    };
}

/** Lookup used by {@link buildSchemaModel} to get the Dataverse metadata of a selected entity. */
export type EntityMetadataLookup = (logicalName: string) => EntityMetadataInput | undefined;

/** Strip non-word characters and make the result a valid identifier (dataverse-gen's `makeCodeSafe`). */
export function makeCodeSafe(name: string): string {
    let safe = name.replace(/[^\w]/gm, '');
    if (safe.startsWith('_') && safe.length > 1) safe = safe.substring(1);
    if (/^\d/.test(safe)) safe = `_${safe}`;
    return safe;
}

interface MappingContext {
    config: ResolvedConfig;
    /** Selected (or referenced) entities, by logical name. */
    entities: Map<string, { Name: string; SchemaName: string }>;
    /** All entity types known to the CSDL, by logical name. */
    allEntityNames: Set<string>;
    complexTypeNames: Set<string>;
    enumNames: Set<string>;
}

function mapTypeName(ctx: MappingContext, typeName: string): string {
    return ctx.config.referencedTypes[typeName]?.name ?? typeName;
}

function resolveImportLocation(ctx: MappingContext, typeName: string, outputType: OutputTypeKind): string | undefined {
    const bare = typeName.replace('[]', '');
    const referenced = ctx.config.referencedTypes[bare];
    if (referenced) return referenced.import;
    switch (outputType) {
        case 'enum':
            return (ctx.config.referencedTypes['enums']?.import ?? '../enums/') + bare;
        case 'entity':
            return (ctx.config.referencedTypes['entityTypes']?.import ?? '../entities/') + bare;
        case 'complex':
            return (ctx.config.referencedTypes['complexTypes']?.import ?? '../complextypes/') + bare;
        default:
            return undefined;
    }
}

function findEntity(ctx: MappingContext, name: string) {
    for (const entity of ctx.entities.values()) {
        if (entity.SchemaName === name || entity.Name === name) return entity;
    }
    return undefined;
}

function findEntityIgnoreCase(ctx: MappingContext, logicalName: string) {
    const lower = logicalName.toLowerCase();
    for (const entity of ctx.entities.values()) {
        if (entity.Name.toLowerCase() === lower) return entity;
    }
    return undefined;
}

/** Port of `SchemaModel.getTypeScriptType`: maps an attribute / property type to a TypeScript type. */
function getTypeScriptType(ctx: MappingContext, property: { Type: string; IsMultiSelect?: boolean; IsEnum?: boolean }): TsType {
    const referencedType = property.Type;
    const isCollection = isCollectionType(referencedType);
    const typeName = stripCollection(referencedType);
    let definitelyTypedFieldType: string | undefined;
    let type = 'any';

    switch (typeName) {
        case 'MultiSelectPicklistType':
            type = 'number[]';
            break;
        case 'PicklistType':
        case 'StateType':
        case 'StatusType':
            type = 'number';
            definitelyTypedFieldType = 'OptionSet';
            break;
        case 'Edm.Guid':
        case 'UniqueidentifierType':
            type = 'Guid';
            break;
        case 'ImageType':
        case 'FileType':
        case 'Edm.String':
        case 'StringType':
        case 'Edm.Duration':
        case 'Edm.Binary':
        case 'MemoType':
        case 'EntityNameType':
            type = 'string';
            definitelyTypedFieldType = 'String';
            break;
        case 'Edm.Int16':
        case 'Edm.Int32':
        case 'BigIntType':
        case 'IntegerType':
        case 'Edm.Int64':
        case 'Edm.Double':
        case 'DoubleType':
        case 'Edm.Decimal':
        case 'DecimalType':
        case 'MoneyType':
            type = 'number';
            definitelyTypedFieldType = 'Number';
            break;
        case 'Edm.Boolean':
        case 'BooleanType':
            type = 'boolean';
            definitelyTypedFieldType = 'Boolean';
            break;
        case 'Edm.DateTimeOffset':
        case 'DateTimeType':
            type = 'Date';
            definitelyTypedFieldType = 'Date';
            break;
        case 'CustomerType':
        case 'LookupType':
        case 'OwnerType':
            type = 'EntityReference';
            definitelyTypedFieldType = 'Lookup';
            break;
        case 'PartyListType':
            type = 'ActivityParty[]';
            definitelyTypedFieldType = 'OptionSet';
            break;
        case 'ManagedPropertyType':
            type = 'number';
            break;
        default:
            type = typeName.includes('.') ? shortTypeName(typeName) : typeName;
            break;
    }

    let isEnum = property.IsEnum === true;
    let outputType: OutputTypeKind = isEnum ? 'enum' : 'primitive';
    if (type === 'crmbaseentity') {
        type = 'any';
    } else {
        if (ctx.enumNames.has(type)) {
            isEnum = true;
            outputType = 'enum';
        }
        // E.g. special case because we don't want an interface called 'Object'
        type = mapTypeName(ctx, type);
        const entity = findEntity(ctx, type);
        if (entity) {
            type = entity.SchemaName;
            outputType = 'entity';
        } else if (outputType === 'primitive' && ctx.allEntityNames.has(type)) {
            // Deviation: dataverse-gen would emit the bare logical name of an entity that is not part
            // of the selection, which does not compile. Fall back to `any` instead.
            type = 'any';
        }
        if (ctx.complexTypeNames.has(type)) outputType = 'complex';
    }
    if (isCollection || property.IsMultiSelect) type = type + '[]';

    // Deviation: dataverse-gen emits `Xrm.Attributes.undefinedAttribute` when the field type is unknown;
    // leave both undefined so the form-context template skips the attribute instead.
    const attributeType = isEnum
        ? 'Xrm.Attributes.OptionSetAttribute'
        : definitelyTypedFieldType
          ? `Xrm.Attributes.${definitelyTypedFieldType}Attribute`
          : undefined;
    const controlType =
        isEnum || property.Type === 'BooleanType'
            ? 'Xrm.Controls.OptionSetControl'
            : definitelyTypedFieldType
              ? `Xrm.Controls.${definitelyTypedFieldType}Control`
              : undefined;

    return {
        name: type,
        outputType,
        importLocation: resolveImportLocation(ctx, type, outputType),
        definitelyTypedAttributeType: attributeType,
        definitelyTypedControlType: controlType,
    };
}

function getStructuralType(ctx: MappingContext, parameter: EdmxParameter): StructuralProperty {
    if (isCollectionType(parameter.Type)) return 'Collection';
    const typeName = shortTypeName(parameter.Type);
    if (parameter.Type.startsWith('mscrm')) {
        if (findEntityIgnoreCase(ctx, typeName)) return 'EntityType';
        if (ctx.enumNames.has(typeName)) return 'EnumerationType';
        return 'ComplexType';
    }
    if (parameter.Type.startsWith('Edm')) return 'PrimitiveType';
    return 'ComplexType';
}

function structuralPropertyToString(value: StructuralProperty): string {
    switch (value) {
        case 'Collection':
            return 'Collection';
        case 'Unknown':
            return 'Unknown';
        case 'PrimitiveType':
            return 'PrimitiveType';
        case 'EnumerationType':
            return 'EnumerationType';
        case 'ComplexType':
        case 'EntityType':
            return 'EntityType';
        default:
            return 'PrimitiveType';
    }
}

/** Port of `SchemaModel.getParameterTypeScriptType` (plus `CorrectFunctionActionEntitySetParameter`). */
function mapParameter(ctx: MappingContext, parameter: EdmxParameter): ParameterModel {
    let typeName = 'any';
    let outputType: OutputTypeKind = 'primitive';
    let structuralType = getStructuralType(ctx, parameter);
    const isCollection = structuralType === 'Collection';
    const paramType = isCollection ? stripCollection(parameter.Type) : parameter.Type;

    if (paramType.startsWith('Edm.')) {
        switch (paramType) {
            case 'Edm.Guid':
                typeName = 'Guid';
                break;
            case 'Edm.String':
            case 'Edm.Duration':
            case 'Edm.Binary':
                typeName = 'string';
                break;
            case 'Edm.Int16':
            case 'Edm.Int32':
            case 'Edm.Int64':
            case 'Edm.Double':
            case 'Edm.Decimal':
                typeName = 'number';
                break;
            case 'Edm.Boolean':
                typeName = 'boolean';
                break;
            case 'Edm.DateTimeOffset':
                typeName = 'Date';
                break;
        }
        if (isCollection) typeName += '[]';
    } else {
        typeName = shortTypeName(paramType);
        if (typeName === 'crmbaseentity') {
            typeName = 'any';
            if (isCollection) typeName += '[]';
        } else {
            if (structuralType === 'ComplexType' && findEntityIgnoreCase(ctx, typeName)) {
                structuralType = 'EntityType';
            }
            const entity = findEntityIgnoreCase(ctx, typeName);
            switch (structuralType) {
                case 'EntityType':
                    outputType = 'entity';
                    typeName = 'EntityReference|' + entity?.SchemaName;
                    break;
                case 'Collection':
                    if (entity) {
                        outputType = 'entity';
                        typeName = `EntityReference[]|${entity.SchemaName}[]`;
                    } else if (ctx.enumNames.has(typeName)) {
                        // Deviation: dataverse-gen treats every collection as an entity collection,
                        // producing `undefined[]` for enum and complex type collections.
                        outputType = 'enum';
                        typeName = typeName + '[]';
                    } else {
                        outputType = 'complex';
                        typeName = mapTypeName(ctx, typeName) + '[]';
                    }
                    break;
                case 'EnumerationType':
                    outputType = 'enum';
                    break;
                default:
                    outputType = 'complex';
                    typeName = mapTypeName(ctx, typeName);
                    break;
            }
        }
    }

    const type = parameter.Name === 'entityset' && structuralType === 'Collection' ? stripCollection(parameter.Type) : parameter.Type;
    return {
        Name: parameter.Name,
        Type: type,
        structuralTypeName: structuralPropertyToString(structuralType),
        TypescriptTypes: typeName.split('|').map((item) => ({
            name: item,
            outputType,
            importLocation: resolveImportLocation(ctx, item, outputType),
        })),
    };
}

function labelText(label: { UserLocalizedLabel?: { Label?: string | null } | null } | null | undefined): string {
    return label?.UserLocalizedLabel?.Label ?? '';
}

/** Port of `SchemaModel.addEnum`. Returns the enum (new or already registered). */
function addEnum(optionSet: OptionSetInput, entityLogicalName: string, enums: EnumModel[], globalEnums: Map<string, EnumModel>): EnumModel {
    const members = optionSet.Options.map((option) => {
        const label = labelText(option.Label);
        let name = '_' + option.Value.toString();
        if (label.length > 0) {
            const safe = makeCodeSafe(label);
            // Deviation: a label made only of non-word characters would produce an empty member name.
            if (safe.length > 0) name = safe;
        }
        return { Name: name, Value: option.Value.toString() };
    });
    const enumModel: EnumModel = {
        Name: optionSet.IsGlobal === true ? optionSet.Name : `${entityLogicalName}_${optionSet.Name}`,
        Members: members,
        StringMembers: false,
    };
    if (optionSet.IsGlobal === true) {
        const existing = globalEnums.get(enumModel.Name);
        if (existing) return existing;
        globalEnums.set(enumModel.Name, enumModel);
    }
    enumModel.Members.sort((a, b) => (Number.parseInt(a.Value) < Number.parseInt(b.Value) ? -1 : 1));
    enums.push(enumModel);
    return enumModel;
}

/** Port of `SchemaModel.addLookupType`: collapse `objectid_account`, `objectid_contact`, … into `objectid`. */
function collapseLookupNavigation(attribute: AttributeMetadataInput, navigation: NavigationModel[]): void {
    const targets = attribute.Targets ?? [];
    if (targets.length === 0) return;
    const prefix = attribute.LogicalName + '_';
    const related = navigation.filter((n) => n.Name.startsWith(prefix));
    if (related.length === 0) return;
    const first = related[0];
    for (const nav of related) {
        const index = navigation.indexOf(nav);
        if (index > -1) navigation.splice(index, 1);
    }
    navigation.push({ Name: attribute.LogicalName, Type: targets.join(','), IsCollection: first.IsCollection });
}

/**
 * Build the full schema model for the selection.
 *
 * @param edmx Parsed CSDL document.
 * @param config Resolved `.dataverse-gen.json` options.
 * @param getEntityMetadata Dataverse metadata for every entity in `resolveSelection(edmx, config).entities`.
 * @throws when metadata (or an attribute's option set) is missing for a required entity.
 */
export function buildSchemaModel(edmx: EdmxSchema, config: ResolvedConfig, getEntityMetadata: EntityMetadataLookup): SchemaModel {
    const selection = resolveSelection(edmx, config);

    const enums: EnumModel[] = selection.enumTypes.map((e) => ({
        Name: e.Name,
        Members: e.Members.map((m) => ({ Name: m.Name, Value: m.Value })),
        StringMembers: true,
    }));
    const globalEnums = new Map<string, EnumModel>();

    // Pass 1: entity metadata — properties, option-set enums and lookup navigation.
    interface EntityDraft {
        model: EntityModel;
        rawProperties: Array<Omit<EntityPropertyModel, 'TypescriptType'>>;
    }
    const drafts: EntityDraft[] = [];
    for (const entityType of selection.entities) {
        const metadata = getEntityMetadata(entityType.Name);
        if (!metadata) {
            throw new Error(`${entityType.Name} is not a Dataverse entity (no metadata available), remove it from the ${'.dataverse-gen.json'}`);
        }
        const navigation: NavigationModel[] = entityType.NavigationProperties.map((n) => ({
            Name: n.Name,
            Type: n.Type,
            IsCollection: n.IsCollection,
        }));
        const attributes = metadata.Attributes.filter((a) => a.AttributeTypeName?.Value !== 'VirtualType').sort((a, b) =>
            a.LogicalName > b.LogicalName ? 1 : -1,
        );
        const rawProperties: EntityDraft['rawProperties'] = [];
        for (const attribute of attributes) {
            const attributeType = attribute.AttributeTypeName?.Value ?? (attribute.AttributeType ? `${attribute.AttributeType}Type` : 'Unknown');
            let typeName = attributeType;
            let dateFormat = '';
            let multiSelect = false;
            let optionSetEnum: EnumModel | undefined;
            switch (attributeType) {
                case 'DateTimeType':
                    dateFormat = `${attribute.Format ?? ''}:${attribute.DateTimeBehavior?.Value}`;
                    break;
                case 'CustomerType':
                case 'LookupType':
                    collapseLookupNavigation(attribute, navigation);
                    break;
                case 'MultiSelectPicklistType':
                case 'PicklistType':
                case 'StatusType':
                case 'StateType': {
                    if (!attribute.OptionSet) {
                        throw new Error(`Option set metadata is missing for ${entityType.Name}.${attribute.LogicalName}`);
                    }
                    multiSelect = attributeType === 'MultiSelectPicklistType';
                    optionSetEnum = addEnum(attribute.OptionSet, metadata.LogicalName, enums, globalEnums);
                    break;
                }
            }
            if (optionSetEnum) typeName = optionSetEnum.Name;
            rawProperties.push({
                Type: typeName,
                Name: attribute.LogicalName,
                SchemaName: attribute.SchemaName,
                IsRequired: attribute.RequiredLevel?.Value === 'ApplicationRequired',
                IsEnum: optionSetEnum !== undefined,
                Description: labelText(attribute.Description),
                DisplayName: labelText(attribute.DisplayName),
                Format: dateFormat,
                IsMultiSelect: multiSelect,
                AttributeOf: attribute.AttributeOf,
                SourceType: attribute.SourceType,
            });
        }
        drafts.push({
            model: {
                Name: entityType.Name,
                SchemaName: metadata.SchemaName,
                EntitySetName: metadata.EntitySetName ?? entityType.EntitySetName ?? '',
                KeyName: entityType.KeyName ?? metadata.PrimaryIdAttribute ?? '',
                Properties: [],
                NavigationProperties: navigation,
            },
            rawProperties,
        });
    }

    // Complex type renames (mscrm.Object -> ObjectValue) happen before type mapping, as in dataverse-gen.
    const complexTypeNames = new Set<string>();
    const renamedComplexTypes = selection.complexTypes.map((c) => {
        const name = config.referencedTypes[c.Name]?.name ?? c.Name;
        complexTypeNames.add(name);
        return { ...c, Name: name };
    });

    const ctx: MappingContext = {
        config,
        entities: new Map(drafts.map((d) => [d.model.Name, { Name: d.model.Name, SchemaName: d.model.SchemaName }])),
        allEntityNames: new Set(edmx.entityTypes.map((e) => e.Name)),
        complexTypeNames,
        enumNames: new Set(enums.map((e) => e.Name)),
    };

    // Pass 2: TypeScript type mapping.
    const entities: EntityModel[] = drafts.map((draft) => ({
        ...draft.model,
        Properties: draft.rawProperties.map((p) => ({ ...p, TypescriptType: getTypeScriptType(ctx, p) })),
    }));

    const complexTypes: ComplexTypeModel[] = renamedComplexTypes.map((c) => ({
        Name: c.Name,
        Properties: c.Properties.map((p) => ({ Name: p.Name, TypescriptType: getTypeScriptType(ctx, { Type: p.Type }) })),
        NavigationProperties: c.NavigationProperties.map((n) => ({
            Name: n.Name,
            TypescriptType: getTypeScriptType(ctx, { Type: n.IsCollection ? `Collection(${n.Type})` : n.Type }),
        })),
    }));

    const mapOperation = (operation: EdmxOperation): OperationModel => ({
        Name: operation.Name,
        IsBound: operation.IsBound,
        Parameters: operation.Parameters.map((p) => mapParameter(ctx, p)),
    });

    return {
        entities: entities.sort(byName),
        enums,
        complexTypes: complexTypes.sort(byName),
        actions: selection.actions.map(mapOperation),
        functions: selection.functions.map(mapOperation),
    };
}
