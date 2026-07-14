import type { PcfControl, PcfFeatureUsage, PcfParameter, PcfResource, PcfTypeGroup } from "../../types";

function api(): typeof window.dataverseAPI {
    return window.dataverseAPI;
}

/**
 * Parses a `customcontrol.manifest` XML string into its `<property>` parameter definitions.
 * Only the `<control>` element's direct `<property>` children are considered. Controls with no
 * `<property>` elements (e.g. dataset/grid-bound controls, which declare a `<data-set>` instead of
 * any `<property>`) correctly return an empty array — every other control-level fact lives on
 * `PcfControl` itself (see `parsePcfManifestControlInfo`), not here, so a control with zero
 * parameters still has everything else available.
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
 * but reads `Properties.Properties[]` instead of the manifest XML's `<property>` elements. Dataset
 * columns live under `Properties.DataSets[]`, not here — this only covers bound/input/output
 * properties, same as the manifest XML version.
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

/** Everything parsed off a `customcontrol.manifest` XML string's `<control>` element: identity
 * attributes (`namespace`/`constructor`/`api-version`), plus its `<built-by>`,
 * `<subscribed-functionality name="sharedTemplate">`, `<resources>`, `<external-service-usage>`,
 * `<type-group>`, and `<feature-usage>` children. */
export interface PcfManifestControlInfo {
    namespace: string;
    constructor: string;
    apiVersion: string;
    builtByName: string;
    builtByVersion: string;
    sharedTemplate: boolean;
    resources: PcfResource[];
    externalDomains: string[];
    typeGroups: PcfTypeGroup[];
    featureUsage: PcfFeatureUsage[];
}

const EMPTY_MANIFEST_CONTROL_INFO: PcfManifestControlInfo = {
    namespace: "",
    constructor: "",
    apiVersion: "",
    builtByName: "",
    builtByVersion: "",
    sharedTemplate: false,
    resources: [],
    externalDomains: [],
    typeGroups: [],
    featureUsage: [],
};

/** Parses a `customcontrol.manifest` XML string's `<control>` element into a {@link PcfManifestControlInfo}.
 * Falls back to all-empty values for an empty/malformed manifest, or one with no `<control>` element. */
export function parsePcfManifestControlInfo(manifestXml: string): PcfManifestControlInfo {
    if (!manifestXml) return EMPTY_MANIFEST_CONTROL_INFO;

    const doc = new DOMParser().parseFromString(manifestXml, "application/xml");
    if (doc.querySelector("parsererror")) return EMPTY_MANIFEST_CONTROL_INFO;

    const control = doc.querySelector("control");
    if (!control) return EMPTY_MANIFEST_CONTROL_INFO;

    const builtBy = control.querySelector("built-by");
    const sharedTemplateEl = control.querySelector('subscribed-functionality[name="sharedTemplate"]');

    const resources: PcfResource[] = [];
    control.querySelectorAll("resources > code").forEach((el) => {
        resources.push(elementToResource(el, "code"));
    });
    control.querySelectorAll("resources > css").forEach((el) => {
        resources.push(elementToResource(el, "css"));
    });
    control.querySelectorAll("resources > resx").forEach((el) => {
        resources.push(elementToResource(el, "resx"));
    });

    const externalDomains = Array.from(control.querySelectorAll("external-service-usage > domain"))
        .map((el) => el.textContent?.trim() ?? "")
        .filter(Boolean);

    const typeGroups: PcfTypeGroup[] = Array.from(control.querySelectorAll("type-group")).map((el) => ({
        name: el.getAttribute("name") ?? "",
        types: Array.from(el.querySelectorAll("type"))
            .map((t) => t.textContent?.trim() ?? "")
            .filter(Boolean),
    }));

    const featureUsage: PcfFeatureUsage[] = Array.from(control.querySelectorAll("feature-usage > uses-feature")).map((el) => ({
        name: el.getAttribute("name") ?? "",
        required: el.getAttribute("required") === "true",
    }));

    return {
        namespace: control.getAttribute("namespace") ?? "",
        constructor: control.getAttribute("constructor") ?? "",
        apiVersion: control.getAttribute("api-version") ?? "",
        builtByName: builtBy?.getAttribute("name") ?? "",
        builtByVersion: builtBy?.getAttribute("version") ?? "",
        sharedTemplate: sharedTemplateEl?.getAttribute("value") === "true",
        resources,
        externalDomains,
        typeGroups,
        featureUsage,
    };
}

/**
 * Determines whether a control is dataset/grid-bound (`"DataSet"`) or field-bound (`"Field"`).
 * `"DataSet"` if either the manifest XML declares a `<data-set>` element, or the clientjson's
 * `Properties.DataSets` array is non-empty — checking both since either can be the more complete
 * source depending on how the control was registered. Malformed/empty input on one side doesn't
 * short-circuit the other.
 */
export function parsePcfTemplateType(manifestXml: string, clientJson: string): "Field" | "DataSet" {
    if (manifestXml) {
        const doc = new DOMParser().parseFromString(manifestXml, "application/xml");
        if (!doc.querySelector("parsererror") && doc.querySelector("control > data-set")) {
            return "DataSet";
        }
    }

    if (clientJson) {
        try {
            const parsed = JSON.parse(clientJson);
            const dataSets = parsed?.Properties?.DataSets;
            if (Array.isArray(dataSets) && dataSets.length > 0) {
                return "DataSet";
            }
        } catch {
            // Fall through to "Field" below.
        }
    }

    return "Field";
}

function elementToResource(el: Element, kind: PcfResource["kind"]): PcfResource {
    const order = el.getAttribute("order");
    return {
        kind,
        path: el.getAttribute("path") ?? "",
        order: order !== null ? Number(order) : undefined,
        version: el.getAttribute("version") ?? undefined,
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
            controlName: name,
            compatibleDataTypes,
            rawManifestXml,
            rawClientJson,
            isVirtual,
            version,
            templateType: parsePcfTemplateType(rawManifestXml, rawClientJson),
            parameters: parsePcfManifestParameters(rawManifestXml),
            ...parsePcfManifestControlInfo(rawManifestXml),
        });
    }

    return controls;
}
