export * from "./bpfprocess";
export * from "./bpfscope";
export * from "./stageinfo";
export * from "./fieldinfo";

/**
 * A fixed, hand-picked "cold to warm" palette for the stage timeline in {@link StagesFieldsCard} (and
 * mirrored by field-detail views that need the same per-stage color), cycling by index if there
 * are more stages than colors. Not derived from Fluent's semantic tokens since it represents an
 * ordered visual sequence across stages, not app theming.
 */
export const STAGE_COLORS = ["#5E85A6", "#4F9490", "#4A9E74", "#6BA355", "#C98A33"];

/** Returns the {@link STAGE_COLORS} entry for a stage at the given index, cycling as needed. */
export function getStageColor(stageIndex: number): string {
    return STAGE_COLORS[stageIndex % STAGE_COLORS.length];
}

export * from "./attributeinfo";
export * from "./entitymetadata";
export * from "./pcffeatureusage";
export * from "./pcfparameter";
export * from "./pcfcontrol";
export * from "./pcfresource";
export * from "./pcftypegroup";

/** Standard Dataverse form-factor codes used on `<customControl formFactor="...">`: `0` = Phone,
 * `1` = Tablet, `2` = Web (desktop). */
export const FORM_FACTORS = [0, 1, 2] as const;
export type FormFactor = (typeof FORM_FACTORS)[number];

/** Display labels for {@link FORM_FACTORS}, keyed by the same numeric code. */
export const FORM_FACTOR_LABELS: Record<FormFactor, string> = {
    0: "Phone",
    1: "Tablet",
    2: "Web",
};

/** Left-to-right tab display order for {@link FORM_FACTORS} in `FormFactorsCard` — purely a UI
 * ordering, independent of the numeric codes themselves (which are fixed by Dataverse and must not
 * change): Web, Tablet, Phone. Everything else that iterates form factors (e.g. building the
 * per-form-factor assignment map) uses {@link FORM_FACTORS} directly, since order doesn't matter there. */
export const FORM_FACTOR_TAB_ORDER: FormFactor[] = [2, 1, 0];

/** Form factor selected by default when a BPF is first loaded — Web (`2`). */
export const DEFAULT_FORM_FACTOR: FormFactor = 2;

export * from "./pcfassignment";
export * from "./solutioninfo";
export * from "./publisherinfo";
export * from "./scope";
export * from "./maintab";
