/** One `<value>` option declared under an `Enum`-typed `<property>` in a PCF manifest. */
export interface PcfEnumValue {
    /** The option's name/key, e.g. `"Value1"`. */
    name: string;
    /** The option's underlying value, e.g. `"1"`. */
    value: string;
}

/** A PCF manifest `<property>` entry. */
export interface PcfParameter {
    name: string;
    displayNameKey: string;
    ofType?: string;
    ofTypeGroup?: string;
    required: boolean;
    /** 'bound' parameters are wired to the field itself and are not user-configurable. */
    usage: string;
    /** The `<value>` options declared under this property, present only for `of-type="Enum"` properties. */
    enumValues?: PcfEnumValue[];
}
