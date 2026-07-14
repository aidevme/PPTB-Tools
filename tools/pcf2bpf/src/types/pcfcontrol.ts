import type { PcfFeatureUsage } from "./pcffeatureusage";
import type { PcfParameter } from "./pcfparameter";
import type { PcfResource } from "./pcfresource";
import type { PcfTypeGroup } from "./pcftypegroup";

/**
 * A registered PCF control (Dataverse `customcontrol` record).
 *
 * @remarks
 * All of this (besides `id` and `parameters`) describes the control as a whole, independent of
 * whether it has any manifest parameters — some controls (e.g. dataset/grid-bound controls, which
 * declare a `<data-set>` instead of any `<property>`) have zero parameters, so none of this can live
 * on `PcfParameter`; a control-level fact must be readable without indexing into a possibly-empty
 * `parameters` array.
 */
export interface PcfControl {
    id: string;
    parameters: PcfParameter[];
    /** Whether this control binds to a single field (`<property>` elements) or a dataset/grid
     * (`<data-set>` in the manifest, or a non-empty `Properties.DataSets` in the clientjson). A
     * control can have `parameters.length === 0` either way — this is what actually distinguishes a
     * dataset-bound control (genuinely no field-style properties) from a malformed/unparsed manifest. */
    templateType: "Field" | "DataSet";
    /** The fully-qualified name (`customcontrol.name`, e.g. `"publisher.Namespace.Control"`). */
    controlName: string;
    /** `customcontrol.compatibledatatypes`, split into individual type names. */
    compatibleDataTypes: string[];
    /** The raw `customcontrol.manifest` XML string, unparsed. */
    rawManifestXml: string;
    /** The raw `customcontrol.clientjson` string, unparsed. */
    rawClientJson: string;
    /** `true` for a virtual (React-rendered) control, `false` for a standard (HTML) control. */
    isVirtual: boolean;
    /** The `<control>` element's `namespace` attribute. */
    namespace: string;
    /** The `<control>` element's `constructor` attribute. */
    constructor: string;
    /** The PCF manifest schema version the control was built against. */
    version: string;
    /** The `<control>` element's `api-version` attribute. */
    apiVersion: string;
    /** The `<built-by>` element's `name` attribute (e.g. `"pac"`). Empty if the manifest has no
     * `<built-by>` element. */
    builtByName: string;
    /** The `<built-by>` element's `version` attribute. Empty if the manifest has no `<built-by>`
     * element. */
    builtByVersion: string;
    /** The `<subscribed-functionality name="sharedTemplate">` element's `value` attribute, parsed as
     * a boolean. `false` if absent. */
    sharedTemplate: boolean;
    /** The manifest's `<resources>` entries (`<code>`/`<css>`/`<resx>`). */
    resources: PcfResource[];
    /** The manifest's `<external-service-usage><domain>` entries. */
    externalDomains: string[];
    /** The manifest's `<type-group>` elements. */
    typeGroups: PcfTypeGroup[];
    /** The manifest's `<feature-usage><uses-feature>` entries. */
    featureUsage: PcfFeatureUsage[];
}
