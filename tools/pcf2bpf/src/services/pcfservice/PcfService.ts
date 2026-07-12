import type { PcfControl, PcfParameter } from "../../types";

function api(): typeof window.dataverseAPI {
    return window.dataverseAPI;
}

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

/** Maps `customcontrol.clientjson`'s numeric `Usage` code to the manifest's string `usage` values. */
const USAGE_BY_CODE: Record<number, string> = {
    0: "bound",
    1: "input",
    2: "output",
};

/**
 * Parses a `customcontrol.clientjson` string (the platform-generated JSON representation of a
 * control's manifest) into its property parameter definitions. Mirrors `parsePcfManifestParameters`
 * but reads `Properties.Properties[]` instead of the manifest XML's `<property>` elements.
 */
export function parsePcfClientJsonParameters(clientJson: string): PcfParameter[] {
    if (!clientJson) return [];

    let parsed: any;
    try {
        parsed = JSON.parse(clientJson);
    } catch {
        return [];
    }

    const properties = parsed?.Properties?.Properties;
    if (!Array.isArray(properties)) return [];

    return properties
        .map((prop): PcfParameter => ({
            name: prop.Name ?? "",
            displayNameKey: prop.Name ?? "",
            ofType: prop.Type ?? undefined,
            ofTypeGroup: prop.TypeGroup ?? undefined,
            required: prop.Required === true,
            usage: USAGE_BY_CODE[prop.Usage] ?? "input",
        }))
        .filter((param) => param.name.length > 0);
}

/** Control-level metadata parsed from `customcontrol.clientjson`, independent of its parameters. */
export interface PcfClientJsonInfo {
    /** `true` for a virtual (React-rendered) control, `false` for a standard (HTML) control. */
    isVirtual: boolean;
    /** The PCF manifest schema version the control was built against (`ControlManifestVersion`). */
    version: string;
}

/** Parses the `IsVirtual` and `ControlManifestVersion` fields out of a `customcontrol.clientjson` string. */
export function parsePcfClientJsonInfo(clientJson: string): PcfClientJsonInfo {
    if (!clientJson) return { isVirtual: false, version: "" };

    let parsed: any;
    try {
        parsed = JSON.parse(clientJson);
    } catch {
        return { isVirtual: false, version: "" };
    }

    return {
        isVirtual: parsed?.IsVirtual === true,
        version: parsed?.ControlManifestVersion ?? "",
    };
}

/** Loads all registered PCF controls (`customcontrol` records) and their manifest parameters. */
export async function loadPcfControls(): Promise<PcfControl[]> {
    const fetchXml = `
        <fetch>
          <entity name="customcontrol">
            <attribute name="customcontrolid" />
            <attribute name="name" />
            <attribute name="compatibledatatypes" />
            <attribute name="manifest" />
            <attribute name="clientjson" />
            <order attribute="name" />
          </entity>
        </fetch>`;

    const result = await api().fetchXmlQuery(fetchXml);
    const controls: PcfControl[] = [];

    for (const record of result.value) {
        const name = record.name ? String(record.name) : "";
        if (!name) continue;

        const compatibleDataTypes = String(record.compatibledatatypes ?? "")
            .split(",")
            .map((t) => t.trim())
            .filter(Boolean);

        const rawManifestXml = String(record.manifest ?? "");
        const rawClientJson = String(record.clientjson ?? "");
        const { isVirtual, version } = parsePcfClientJsonInfo(rawClientJson);

        controls.push({
            id: String(record.customcontrolid ?? ""),
            name,
            compatibleDataTypes,
            parameters: parsePcfManifestParameters(rawManifestXml),
            isVirtual,
            version,
            rawManifestXml,
            rawClientJson,
        });
    }

    return controls;
}
