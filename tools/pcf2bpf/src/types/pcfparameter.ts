import type { PcfFeatureUsage } from "./pcffeatureusage";
import type { PcfResource } from "./pcfresource";
import type { PcfTypeGroup } from "./pcftypegroup";

/** A PCF manifest `<property>` entry. */
export interface PcfParameter {
    name: string;
    displayNameKey: string;
    ofType?: string;
    ofTypeGroup?: string;
    required: boolean;
    /** 'bound' parameters are wired to the field itself and are not user-configurable. */
    usage: string;
    /** The raw `customcontrol.manifest` XML string of the control this parameter belongs to,
     * unparsed. Same value repeated on every parameter from that control. */
    rawManifestXml: string;
    /** The raw `customcontrol.clientjson` string of the control this parameter belongs to,
     * unparsed. Same value repeated on every parameter from that control. */
    rawClientJson: string;
    /** `true` for a virtual (React-rendered) control, `false` for a standard (HTML) control. Same
     * value repeated on every parameter from that control. */
    isVirtual: boolean;
    /** The `<control>` element's `namespace` attribute. Same value repeated on every parameter from
     * that control. */
    namespace: string;
    /** The `<control>` element's `constructor` attribute. Same value repeated on every parameter
     * from that control. */
    constructor: string;
    /** The fully-qualified name (`customcontrol.name`, e.g. `"publisher.Namespace.Control"`) of the
     * control this parameter belongs to. Distinct from `name` above, which is this parameter's own
     * name. Same value repeated on every parameter from that control. */
    controlName: string;
    /** `customcontrol.compatibledatatypes`, split into individual type names, for the control this
     * parameter belongs to. Same value repeated on every parameter from that control. */
    compatibleDataTypes: string[];
    /** The PCF manifest schema version the control this parameter belongs to was built against.
     * Same value repeated on every parameter from that control. */
    version: string;
    /** The `<control>` element's `api-version` attribute. Same value repeated on every parameter
     * from that control. */
    apiVersion: string;
    /** The `<built-by>` element's `name` attribute (e.g. `"pac"`). Empty if the manifest has no
     * `<built-by>` element. Same value repeated on every parameter from that control. */
    builtByName: string;
    /** The `<built-by>` element's `version` attribute. Empty if the manifest has no `<built-by>`
     * element. Same value repeated on every parameter from that control. */
    builtByVersion: string;
    /** The `<subscribed-functionality name="sharedTemplate">` element's `value` attribute, parsed as
     * a boolean. `false` if absent. Same value repeated on every parameter from that control. */
    sharedTemplate: boolean;
    /** The manifest's `<resources>` entries (`<code>`/`<css>`/`<resx>`). Same value repeated on
     * every parameter from that control. */
    resources: PcfResource[];
    /** The manifest's `<external-service-usage><domain>` entries. Same value repeated on every
     * parameter from that control. */
    externalDomains: string[];
    /** The manifest's `<type-group>` elements. Same value repeated on every parameter from that
     * control. */
    typeGroups: PcfTypeGroup[];
    /** The manifest's `<feature-usage><uses-feature>` entries. Same value repeated on every
     * parameter from that control. */
    featureUsage: PcfFeatureUsage[];
}
