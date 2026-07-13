import { DataVizPalette, getColorFromToken } from "@fluentui/react-charts";
import type { PcfParameter, PcfTypeGroup } from "../../services";

/** Coarse-grained bucket a manifest parameter's Dataverse type falls into, used to group the
 * "Property type mix" donut chart in `PcfDetailsPanel`. */
export type PcfParameterCategory = "text" | "number" | "choice" | "date" | "lookup" | "object" | "other";

/** Fixed draw order for {@link PcfParameterCategory} — categorical hues are assigned by position in
 * this list (mapped 1:1 onto `DataVizPalette.color1`, `.color2`, …), never cycled, per the data-viz
 * skill's color-formula rule of a fixed hue order. */
export const CATEGORY_ORDER: PcfParameterCategory[] = ["text", "number", "choice", "date", "lookup", "object", "other"];

export const CATEGORY_LABELS: Record<PcfParameterCategory, string> = {
    text: "Text",
    number: "Number",
    choice: "Choice",
    date: "Date",
    lookup: "Lookup",
    object: "Object",
    other: "Other",
};

/** Fluent's own `DataVizPalette` slots, assigned to {@link PcfParameterCategory} in `CATEGORY_ORDER`
 * — reused (rather than a hand-picked hex set) so the donut chart, its legend, and the Properties
 * tab's type swatches all draw from the same accessible, theme-aware chart palette `DonutChart`
 * itself uses. */
export const CATEGORY_COLORS: Record<PcfParameterCategory, string> = {
    text: getColorFromToken(DataVizPalette.color1),
    number: getColorFromToken(DataVizPalette.color2),
    choice: getColorFromToken(DataVizPalette.color3),
    date: getColorFromToken(DataVizPalette.color4),
    lookup: getColorFromToken(DataVizPalette.color5),
    object: getColorFromToken(DataVizPalette.color6),
    other: getColorFromToken(DataVizPalette.color7),
};

const NUMBER_TYPES = /^(Whole\.|Currency$|FP$|Decimal$)/;
const CHOICE_TYPES = /^(OptionSet|MultiSelectOptionSet|TwoOptions|Enum)$/;
const TEXT_TYPES = /^(SingleLine\.|Multiple$)/;

/** Classifies a manifest type name (an `of-type` value, or an `of-type-group`'s resolved member
 * type) into a {@link PcfParameterCategory}. */
function categorizeTypeName(typeName: string): PcfParameterCategory {
    if (typeName.startsWith("DateAndTime.")) return "date";
    if (NUMBER_TYPES.test(typeName)) return "number";
    if (CHOICE_TYPES.test(typeName)) return "choice";
    if (typeName.startsWith("Lookup")) return "lookup";
    if (typeName === "Object") return "object";
    if (TEXT_TYPES.test(typeName)) return "text";
    return "other";
}

/**
 * Categorizes a manifest parameter for the type-mix donut. Prefers `ofType` directly; when only
 * `ofTypeGroup` is set (e.g. `"texts"`), resolves it against the manifest's `<type-group>`
 * definitions and categorizes the group's first member type — falling back to categorizing the
 * group name itself if it isn't a recognized `<type-group>` (some manifests reuse Dataverse's
 * built-in group names like `"numbers"` without redeclaring them).
 */
export function categorizePcfParameter(param: PcfParameter, typeGroups: PcfTypeGroup[]): PcfParameterCategory {
    if (param.ofType) return categorizeTypeName(param.ofType);

    if (param.ofTypeGroup) {
        const group = typeGroups.find((g) => g.name === param.ofTypeGroup);
        if (group?.types.length) return categorizeTypeName(group.types[0]);
        return categorizeTypeName(param.ofTypeGroup);
    }

    return "other";
}
