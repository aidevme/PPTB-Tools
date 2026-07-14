/** A data field on a BPF stage, rendered from `<control datafieldname="...">` nodes. */
export interface FieldInfo {
    /** The field's `<control>` node's `uniqueid` attribute (a GUID) — the value that
     * `<controlDescriptions><controlDescription forControl="...">` matches against to link this
     * field to its PCF override. Distinct from the `<control>` node's own `id` attribute (a
     * composite `"relationship:datafieldname"` string), which is unrelated to that linkage. */
    controlId: string;
    datafieldname: string;
    label: string;
    /** classid of the field's default renderer, read from the existing `<control>` node. */
    classId: string | null;
    /** id of the {@link StageInfo} this field belongs to, i.e. the `<tab>` it was read from. */
    stageId: string;
    /** Whether the field is marked required on this stage (`<control isrequired="...">`). */
    required: boolean;
    /** 1-based position of the field within its stage, in form XML document order. */
    sequence: number;
    /** Logical name of the entity this field belongs to. Resolved from the field's own
     * `<control relationship="...">` attribute (see `getFieldEntityLogicalName`) since
     * multi-entity BPFs (e.g. a Lead → Opportunity sales process) have fields from different
     * entities; falls back to the BPF's own `primaryentity` when `relationship` is absent or
     * doesn't match the expected shape (e.g. single-entity BPFs). */
    entityLogicalName: string;
}
