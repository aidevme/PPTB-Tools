import { useCallback, useMemo } from "react";
import { getBindableAttributeTypes } from "../services";
import { useToolContext } from "../services/pptbtoolcontextservice";

// Placeholder field choices for the "bind to field" Dropdown shown when "Is Static?" is unchecked,
// for PCF parameter types with no real Dataverse AttributeType mapping yet (see
// `getBindableAttributeTypes`). Not wired to real entity metadata — field-binding for these types
// isn't implemented in this port.
const MOCK_BIND_FIELD_OPTIONS = ["fullname", "emailaddress1", "telephone1", "address1_city", "parentcustomerid"];

/**
 * Returns a resolver — `(paramType) => string[]` — for the field logical names on `entityLogicalName`
 * that are valid bind targets for a PCF parameter of the given type, for `PcfConfiguratorTable`'s
 * "Param Value" Dropdown (shown when a parameter isn't static).
 *
 * @remarks
 * Returns a resolver function rather than a value because the table needs one lookup per row inside a
 * `.map()`, where the Rules of Hooks forbid calling a hook per-iteration; call this hook once per
 * table and invoke the returned function for each parameter.
 *
 * Falls back to a hardcoded placeholder list for any PCF parameter type not (yet) mapped to a real
 * Dataverse `AttributeType` by `getBindableAttributeTypes` — see that function's doc for why the
 * mapping is intentionally narrower than `ATTRIBUTE_TYPE_TO_PCF_TYPES`.
 */
export function useBindFieldOptions(entityLogicalName: string): (paramType: string) => string[] {
    const { entityMetadataInfos } = useToolContext();

    const attributes = useMemo(
        () => entityMetadataInfos.find((e) => e.logicalName === entityLogicalName)?.attributes ?? [],
        [entityMetadataInfos, entityLogicalName],
    );

    return useCallback(
        (paramType: string) => {
            const bindableTypes = getBindableAttributeTypes(paramType);
            if (bindableTypes.length === 0) return MOCK_BIND_FIELD_OPTIONS;

            const wanted = new Set(bindableTypes);
            return attributes.filter((a) => wanted.has(a.attributeType)).map((a) => a.logicalName);
        },
        [attributes],
    );
}
