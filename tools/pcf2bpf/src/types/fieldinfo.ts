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
