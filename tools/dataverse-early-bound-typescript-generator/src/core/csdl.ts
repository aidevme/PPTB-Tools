/**
 * CSDL (`$metadata` EDMX) parser.
 *
 * Reads only what the generator needs: entity types (with keys, properties and navigation properties),
 * entity sets, complex types, enum types, actions and functions. Uses `DOMParser`, so it runs in the
 * browser sandbox PPTB gives tools; a Node consumer can pass its own `DOMParser`-compatible
 * implementation (e.g. `@xmldom/xmldom`).
 */
import type {
    EdmxComplexType,
    EdmxEntityType,
    EdmxEnumType,
    EdmxNavigationProperty,
    EdmxOperation,
    EdmxParameter,
    EdmxProperty,
    EdmxSchema,
} from './types';

export interface XmlParser {
    parseFromString(text: string, type: 'text/xml' | 'application/xml'): Document;
}

/** dataverse-gen drops these EDMX base/system types from the entity list. */
const SYSTEM_ENTITY_TYPES = new Set(['crmbaseentity', 'principal', 'crmmodelbaseentity', 'expando']);

export function isCollectionType(type: string | undefined | null): boolean {
    return !!type && type.startsWith('Collection(');
}

export function stripCollection(type: string): string {
    if (!type.startsWith('Collection(')) return type;
    const inner = type.substring('Collection('.length);
    return inner.endsWith(')') ? inner.substring(0, inner.length - 1) : inner;
}

/** Last dot-separated segment: `mscrm.account` → `account`, `Edm.String` → `String`. */
export function shortTypeName(type: string): string {
    const parts = stripCollection(type).split('.').filter((p) => p !== '');
    return parts[parts.length - 1] ?? type;
}

function childElements(parent: Element, localName: string): Element[] {
    const result: Element[] = [];
    for (let i = 0; i < parent.childNodes.length; i++) {
        const node = parent.childNodes[i];
        if (node.nodeType === 1 && (node as Element).localName === localName) result.push(node as Element);
    }
    return result;
}

function readProperties(owner: Element): EdmxProperty[] {
    const properties = childElements(owner, 'Property').map((p) => ({
        Name: p.getAttribute('Name') ?? '',
        Type: p.getAttribute('Type') ?? '',
        Nullable: p.getAttribute('Nullable') !== 'false',
    }));
    return properties.sort((a, b) => (a.Name > b.Name ? 1 : -1));
}

function readNavigationProperties(owner: Element): EdmxNavigationProperty[] {
    const navigation = childElements(owner, 'NavigationProperty').map((n) => {
        const fullName = n.getAttribute('Name') ?? '';
        const rawType = n.getAttribute('Type') ?? '';
        const type = stripCollection(rawType);
        return {
            Name: fullName.split('.').pop() ?? fullName,
            FullName: fullName,
            IsCollection: isCollectionType(rawType),
            Type: type,
            LogicalName: type.includes('.') ? (type.split('.').pop() as string) : type,
        };
    });
    return navigation.sort((a, b) => (a.Name > b.Name ? 1 : -1));
}

function readOperation(element: Element): EdmxOperation {
    const returnType = childElements(element, 'ReturnType')[0]?.getAttribute('Type') ?? undefined;
    const parameters: EdmxParameter[] = childElements(element, 'Parameter').map((p) => ({
        Name: p.getAttribute('Name') ?? '',
        Type: p.getAttribute('Type') ?? '',
        Nullable: p.getAttribute('Nullable') !== 'false',
    }));
    return {
        Name: element.getAttribute('Name') ?? '',
        IsBound: element.getAttribute('IsBound') === 'true',
        ReturnType: returnType ? stripCollection(returnType) : undefined,
        ReturnsCollection: isCollectionType(returnType),
        Parameters: parameters,
    };
}

/**
 * Parse a `$metadata` document into an {@link EdmxSchema}.
 *
 * Entity types, complex types, actions and functions are sorted by name (as dataverse-gen does);
 * enum types keep document order.
 */
export function parseCsdl(xml: string, parser: XmlParser = new DOMParser()): EdmxSchema {
    const doc = parser.parseFromString(xml, 'text/xml');
    const parseError = doc.getElementsByTagName('parsererror')[0];
    if (parseError) {
        throw new Error(`Could not parse the CSDL document: ${parseError.textContent?.trim().split('\n')[0] ?? 'unknown error'}`);
    }
    const schemas = Array.from(doc.getElementsByTagNameNS('*', 'Schema'));
    if (schemas.length === 0) throw new Error('The CSDL document contains no <Schema> element');

    const entityTypes: EdmxEntityType[] = [];
    const complexTypes: EdmxComplexType[] = [];
    const enumTypes: EdmxEnumType[] = [];
    const actions: EdmxOperation[] = [];
    const functions: EdmxOperation[] = [];
    const entitySets = new Map<string, string>(); // entity type (qualified) -> entity set name

    for (const schema of schemas) {
        for (const e of childElements(schema, 'EntityType')) {
            const key = childElements(e, 'Key')[0];
            const propertyRef = key ? childElements(key, 'PropertyRef')[0] : undefined;
            entityTypes.push({
                Name: e.getAttribute('Name') ?? '',
                BaseType: e.getAttribute('BaseType') ?? undefined,
                Abstract: e.getAttribute('Abstract') === 'true',
                KeyName: propertyRef?.getAttribute('Name') ?? undefined,
                Properties: readProperties(e),
                NavigationProperties: readNavigationProperties(e),
            });
        }
        for (const c of childElements(schema, 'ComplexType')) {
            complexTypes.push({
                Name: c.getAttribute('Name') ?? '',
                Properties: readProperties(c),
                NavigationProperties: readNavigationProperties(c),
            });
        }
        for (const en of childElements(schema, 'EnumType')) {
            enumTypes.push({
                Name: en.getAttribute('Name') ?? '',
                Members: childElements(en, 'Member').map((m) => ({
                    Name: m.getAttribute('Name') ?? '',
                    Value: m.getAttribute('Value') ?? '',
                })),
            });
        }
        for (const a of childElements(schema, 'Action')) actions.push(readOperation(a));
        for (const f of childElements(schema, 'Function')) functions.push(readOperation(f));
        for (const container of childElements(schema, 'EntityContainer')) {
            for (const set of childElements(container, 'EntitySet')) {
                const type = set.getAttribute('EntityType');
                const name = set.getAttribute('Name');
                if (type && name) entitySets.set(type, name);
            }
        }
    }

    const byName = <T extends { Name: string }>(a: T, b: T) => (a.Name > b.Name ? 1 : -1);
    const filteredEntityTypes = entityTypes.filter((e) => !SYSTEM_ENTITY_TYPES.has(e.Name)).sort(byName);
    for (const entity of filteredEntityTypes) {
        if (entity.Abstract || !entity.KeyName) continue;
        entity.EntitySetName = entitySets.get('Microsoft.Dynamics.CRM.' + entity.Name) ?? entitySets.get('mscrm.' + entity.Name);
    }

    return {
        entityTypes: filteredEntityTypes,
        complexTypes: complexTypes.sort(byName),
        enumTypes,
        actions: actions.sort(byName),
        functions: functions.sort(byName),
    };
}
