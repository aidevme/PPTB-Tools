/** A PCF manifest `<property>` entry. */
export interface PcfParameter {
    name: string;
    displayNameKey: string;
    ofType?: string;
    ofTypeGroup?: string;
    required: boolean;
    /** 'bound' parameters are wired to the field itself and are not user-configurable. */
    usage: string;
}
