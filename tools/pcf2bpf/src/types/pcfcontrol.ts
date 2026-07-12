import type { PcfParameter } from "./pcfparameter";

/** A registered PCF control (Dataverse `customcontrol` record). */
export interface PcfControl {
    id: string;
    name: string;
    compatibleDataTypes: string[];
    parameters: PcfParameter[];
    /** `true` for a virtual (React-rendered) control, `false` for a standard (HTML) control. */
    isVirtual: boolean;
    /** The PCF manifest schema version the control was built against. */
    version: string;
    /** The raw `customcontrol.manifest` XML string, unparsed. */
    rawManifestXml: string;
    /** The raw `customcontrol.clientjson` string, unparsed. */
    rawClientJson: string;
}
