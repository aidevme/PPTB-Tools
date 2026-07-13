/** A `<type-group>` element from a `customcontrol.manifest` XML string, listing the concrete
 * Dataverse attribute types a manifest parameter's `of-type-group` name expands to. */
export interface PcfTypeGroup {
    name: string;
    types: string[];
}
