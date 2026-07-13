/** One `<resources>` entry (`<code>`, `<css>`, or `<resx>`) from a `customcontrol.manifest` XML string. */
export interface PcfResource {
    kind: "code" | "css" | "resx";
    path: string;
    order?: number;
    /** `<resx>`'s `version` attribute; absent for `<code>`/`<css>`. */
    version?: string;
}
