import type { PcfControl, PcfFeatureUsage, PcfParameter, PcfResource, PcfTypeGroup } from "../../types";

function api(): typeof window.dataverseAPI {
    return window.dataverseAPI;
}

/** Everything parsed off the `<control>` element itself (attributes and child elements) besides
 * `namespace`/`constructor`, which the caller already needs separately for `PcfParameter`. */
interface PcfManifestControlDetails {
    apiVersion: string;
    builtByName: string;
    builtByVersion: string;
    sharedTemplate: boolean;
    resources: PcfResource[];
    externalDomains: string[];
    typeGroups: PcfTypeGroup[];
    featureUsage: PcfFeatureUsage[];
}

/** Parses the `<control>` element's `api-version` attribute, `<built-by>`, `<subscribed-functionality
 * name="sharedTemplate">`, `<resources>`, `<external-service-usage>`, `<type-group>`, and
 * `<feature-usage>` children. `control` is `null` when the manifest has no `<control>` element (e.g.
 * empty/malformed manifest); every field falls back to its empty value in that case. */
function parseManifestControlDetails(control: Element | null): PcfManifestControlDetails {
    if (!control) {
        return {
            apiVersion: "",
            builtByName: "",
            builtByVersion: "",
            sharedTemplate: false,
            resources: [],
            externalDomains: [],
            typeGroups: [],
            featureUsage: [],
        };
    }

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

function elementToResource(el: Element, kind: PcfResource["kind"]): PcfResource {
    const order = el.getAttribute("order");
    return {
        kind,
        path: el.getAttribute("path") ?? "",
        order: order !== null ? Number(order) : undefined,
        version: el.getAttribute("version") ?? undefined,
    };
}

/**
 * Fields that describe a `customcontrol` record as a whole rather than any one manifest parameter,
 * but that `PcfParameter` still carries (same value repeated on every parameter from that control) —
 * see the matching JSDoc on each `PcfParameter` field. Grouped into one object instead of separate
 * positional arguments since most are same-typed strings, easy to transpose by accident.
 */
export interface PcfControlContext {
    rawClientJson: string;
    isVirtual: boolean;
    /** `customcontrol.name`, e.g. `"publisher.Namespace.Control"`. */
    controlName: string;
    compatibleDataTypes: string[];
    version: string;
}

/**
 * Parses a `customcontrol.manifest` XML string into its `<property>` parameter definitions.
 * Only the `<control>` element's direct `<property>` children are considered. `manifestXml` and
 * every field of `context`, plus the `<control>` element's own `namespace`/`constructor`
 * attributes, are stamped onto every returned parameter as-is — see `PcfControlContext` and the
 * matching `PcfParameter` fields.
 */
export function parsePcfManifestParameters(manifestXml: string, context: PcfControlContext): PcfParameter[] {
    if (!manifestXml) return [];

    const doc = new DOMParser().parseFromString(manifestXml, "application/xml");
    if (doc.querySelector("parsererror")) return [];

    const control = doc.querySelector("control");
    const namespace = control?.getAttribute("namespace") ?? "";
    const constructorName = control?.getAttribute("constructor") ?? "";
    const controlDetails = parseManifestControlDetails(control);

    return Array.from(doc.querySelectorAll("control > property"))
        .map((prop): PcfParameter => ({
            name: prop.getAttribute("name") ?? "",
            displayNameKey: prop.getAttribute("display-name-key") ?? prop.getAttribute("name") ?? "",
            ofType: prop.getAttribute("of-type") ?? undefined,
            ofTypeGroup: prop.getAttribute("of-type-group") ?? undefined,
            required: prop.getAttribute("required") === "true",
            usage: prop.getAttribute("usage") ?? "input",
            rawManifestXml: manifestXml,
            namespace,
            constructor: constructorName,
            ...controlDetails,
            ...context,
        }))
        .filter((param) => param.name.length > 0);
}

/** Maps `customcontrol.clientjson`'s numeric `Usage` code to the manifest's string `usage` values. */
const USAGE_BY_CODE: Record<number, string> = {
    0: "bound",
    1: "input",
    2: "output",
};
/** Control-level metadata parsed from `customcontrol.clientjson`, independent of its parameters. */
export interface PcfClientJsonInfo {
    /** `true` for a virtual (React-rendered) control, `false` for a standard (HTML) control. */
    isVirtual: boolean;
    /** The PCF manifest schema version the control was built against (`ControlManifestVersion`). */
    version: string;
}

/**
 * Parses a `customcontrol.clientjson` string (the platform-generated JSON representation of a
 * control's manifest) into its property parameter definitions. Mirrors `parsePcfManifestParameters`
 * but reads `Properties.Properties[]` instead of the manifest XML's `<property>` elements.
 * `rawManifestXml` and `context` (the fields that don't come from `clientJson` itself — see
 * `PcfControlContext`) are stamped onto every returned parameter as-is; `isVirtual`, `namespace`,
 * and `constructor` are instead read straight off this same `clientJson` payload's
 * `IsVirtual`/`Namespace`/`Constructor` fields, same as in `parsePcfManifestParameters`. The
 * `<control>`-child-element fields (`resources`, `externalDomains`, `typeGroups`, `featureUsage`,
 * `builtByName`/`Version`, `apiVersion`, `sharedTemplate`) have no `clientJson` equivalent, so they
 * fall back to their empty values — only `parsePcfManifestParameters` (the manifest XML, which
 * `loadPcfControls` actually uses) populates them.
 */
export function parsePcfClientJsonParameters(
    clientJson: string,
    rawManifestXml: string,
    context: Pick<PcfControlContext, "controlName" | "compatibleDataTypes" | "version">,
): PcfParameter[] {
    if (!clientJson) return [];

    let parsed: any;
    try {
        parsed = JSON.parse(clientJson);
    } catch {
        return [];
    }

    const properties = parsed?.Properties?.Properties;
    if (!Array.isArray(properties)) return [];

    const isVirtual = parsed?.IsVirtual === true;
    const namespace = parsed?.Namespace ?? "";
    const constructorName = parsed?.Constructor ?? "";
    const controlDetails = parseManifestControlDetails(null);

    return properties
        .map((prop): PcfParameter => ({
            name: prop.Name ?? "",
            displayNameKey: prop.Name ?? "",
            ofType: prop.Type ?? undefined,
            ofTypeGroup: prop.TypeGroup ?? undefined,
            required: prop.Required === true,
            usage: USAGE_BY_CODE[prop.Usage] ?? "input",
            rawManifestXml,
            rawClientJson: clientJson,
            isVirtual,
            namespace,
            constructor: constructorName,
            ...controlDetails,
            ...context,
        }))
        .filter((param) => param.name.length > 0);
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
            parameters: parsePcfManifestParameters(rawManifestXml, {
                rawClientJson,
                isVirtual,
                controlName: name,
                compatibleDataTypes,
                version,
            }),
        });
    }

    return controls;
}
