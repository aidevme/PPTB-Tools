export * from "./bpfprocess";
export * from "./stageinfo";
export * from "./fieldinfo";

/**
 * A fixed, hand-picked "cold to warm" palette for the stage timeline in {@link StagesFields} (and
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
export * from "./pcfparameter";
export * from "./pcfcontrol";

/** Standard Dataverse form-factor codes used on `<customControl formFactor="...">`. */
export const FORM_FACTORS = [0, 1, 2] as const;
export type FormFactor = (typeof FORM_FACTORS)[number];

/** Display labels for {@link FORM_FACTORS}, keyed by the same numeric code. */
export const FORM_FACTOR_LABELS: Record<FormFactor, string> = {
    0: "Web",
    1: "Phone",
    2: "Tablet",
};

export * from "./pcfassignment";
export * from "./solutioninfo";
export * from "./publisherinfo";
