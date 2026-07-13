import type { PcfParameter } from "./pcfparameter";

/** A registered PCF control (Dataverse `customcontrol` record). */
export interface PcfControl {
    id: string;
    parameters: PcfParameter[];
}
