/** An existing PCF assignment read back from form XML for a given field + form factor. */
export interface PcfAssignment {
    name: string;
    parameters: Record<string, string>;
}
