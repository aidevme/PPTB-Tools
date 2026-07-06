/** A Business Process Flow definition (Dataverse `workflow` record with category = 4). */
export interface BpfProcess {
    workflowid: string;
    name: string;
    uniquename: string;
    primaryentity: string;
}

/** A stage in a BPF, rendered from the `<tab>` nodes of the BPF's form XML. */
export interface StageInfo {
    id: string;
    name: string;
}

/** A data field on a BPF stage, rendered from `<control datafieldname="...">` nodes. */
export interface FieldInfo {
    controlId: string;
    datafieldname: string;
    label: string;
    /** classid of the field's default renderer, read from the existing `<control>` node. */
    classId: string | null;
    /** id of the {@link StageInfo} this field belongs to, i.e. the `<tab>` it was read from. */
    stageId: string;
    /** Whether the field is marked required on this stage (`<control isrequired="...">`). */
    required: boolean;
}

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

/** Dataverse attribute metadata, trimmed to what PCF-compatibility filtering needs. */
export interface AttributeInfo {
    logicalName: string;
    displayName: string;
    attributeType: string;
}

/** A PCF manifest `<property>` entry. */
export interface PcfParameter {
    name: string;
    displayNameKey: string;
    ofType?: string;
    ofTypeGroup?: string;
    required: boolean;
    /** 'bound' parameters are wired to the field itself and are not user-configurable. */
    usage: string;
}

/** A registered PCF control (Dataverse `customcontrol` record). */
export interface PcfControl {
    id: string;
    name: string;
    compatibleDataTypes: string[];
    parameters: PcfParameter[];
}

/** Standard Dataverse form-factor codes used on `<customControl formFactor="...">`. */
export const FORM_FACTORS = [0, 1, 2] as const;
export type FormFactor = (typeof FORM_FACTORS)[number];

/** Display labels for {@link FORM_FACTORS}, keyed by the same numeric code. */
export const FORM_FACTOR_LABELS: Record<FormFactor, string> = {
    0: "Web",
    1: "Phone",
    2: "Tablet",
};

/** An existing PCF assignment read back from form XML for a given field + form factor. */
export interface PcfAssignment {
    name: string;
    parameters: Record<string, string>;
}
