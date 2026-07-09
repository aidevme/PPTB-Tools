import type { PcfParameter } from "../types";

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
