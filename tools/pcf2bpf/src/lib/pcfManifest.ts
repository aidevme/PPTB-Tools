import type { PcfParameter } from "./types";

/**
 * Parses a `customcontrol.manifest` XML string into its `<property>` parameter definitions.
 * Only the `<control>` element's direct `<property>` children are considered.
 */
export function parsePcfManifestParameters(manifestXml: string): PcfParameter[] {
    if (!manifestXml) return [];

    const doc = new DOMParser().parseFromString(manifestXml, "application/xml");
    if (doc.querySelector("parsererror")) return [];

    return Array.from(doc.querySelectorAll("control > property"))
        .map((prop): PcfParameter => ({
            name: prop.getAttribute("name") ?? "",
            displayNameKey: prop.getAttribute("display-name-key") ?? prop.getAttribute("name") ?? "",
            ofType: prop.getAttribute("of-type") ?? undefined,
            ofTypeGroup: prop.getAttribute("of-type-group") ?? undefined,
            required: prop.getAttribute("required") === "true",
            usage: prop.getAttribute("usage") ?? "input",
        }))
        .filter((param) => param.name.length > 0);
}
