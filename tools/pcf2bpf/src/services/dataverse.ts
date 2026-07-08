import { parsePcfManifestParameters } from "./pcfManifest";
import type { AttributeInfo, BpfProcess, PcfControl, PublisherInfo, SolutionInfo } from "../types";

/** Maps Dataverse attribute types to the PCF manifest `of-type` values they satisfy. */
const ATTRIBUTE_TYPE_TO_PCF_TYPES: Record<string, string[]> = {
    String: ["SingleLine.Text", "SingleLine.Email", "SingleLine.Phone", "SingleLine.URL", "SingleLine.Ticker", "SingleLine.TextArea"],
    Memo: ["Multiple"],
    Integer: ["Whole.None"],
    BigInt: ["Whole.None"],
    Decimal: ["Decimal"],
    Double: ["FP"],
    Money: ["Currency"],
    DateTime: ["DateAndTime.DateAndTime", "DateAndTime.DateOnly"],
    Boolean: ["TwoOptions"],
    Picklist: ["OptionSet"],
    State: ["OptionSet"],
    Status: ["OptionSet"],
    MultiSelectPicklist: ["MultiSelectPicklist"],
    Lookup: ["Lookup.Simple"],
    Customer: ["Lookup.Customer"],
    Owner: ["Lookup.Owner"],
    Uniqueidentifier: ["SingleLine.Text"],
};

/** Friendly display labels for raw Dataverse `AttributeType` values, for UI display only. */
const ATTRIBUTE_TYPE_LABELS: Record<string, string> = {
    String: "Single Line Text",
    Memo: "Multiline Text",
    Integer: "Whole Number",
    BigInt: "Whole Number",
    Decimal: "Decimal Number",
    Double: "Floating Point Number",
    Money: "Currency",
    DateTime: "Date and Time",
    Boolean: "Two Options",
    Picklist: "Choice",
    State: "Status Reason",
    Status: "Status",
    MultiSelectPicklist: "Choices",
    Lookup: "Lookup",
    Customer: "Customer",
    Owner: "Owner",
    Uniqueidentifier: "Unique Identifier",
};

/** Returns a human-friendly label for a raw Dataverse `AttributeType`, or the type itself if unmapped. */
export function getAttributeTypeLabel(attributeType: string): string {
    return ATTRIBUTE_TYPE_LABELS[attributeType] ?? attributeType;
}

function api(): typeof window.dataverseAPI {
    return window.dataverseAPI;
}

function escapeXmlAttr(value: string): string {
    return value.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

/** Loads all Business Process Flow definitions (`workflow` records with category = 4). */
export async function loadBpfProcesses(): Promise<BpfProcess[]> {
    const fetchXml = `
        <fetch>
          <entity name="workflow">
            <attribute name="workflowid" />
            <attribute name="name" />
            <attribute name="uniquename" />
            <attribute name="primaryentity" />
            <attribute name="xaml" />
            <filter type="and">
              <condition attribute="category" operator="eq" value="4" />
            </filter>
            <order attribute="name" />
          </entity>
        </fetch>`;

    const result = await api().fetchXmlQuery(fetchXml);
    return result.value.map((r) => ({
        workflowid: String(r.workflowid ?? ""),
        name: String(r.name ?? ""),
        uniquename: String(r.uniquename ?? ""),
        primaryentity: String(r.primaryentity ?? ""),
        xaml: String(r.xaml ?? ""),
    }));
}

/**
 * Loads the Business Process Flow's own form (its hidden entity only ever has one form).
 *
 * @throws If the BPF's private entity's `ObjectTypeCode` can't be resolved via entity metadata.
 * @throws If no `systemform` record is found for that entity.
 */
export async function loadBpfFormXml(bpf: BpfProcess): Promise<{ formId: string; formXml: string }> {
    // systemform.objecttypecode is an EntityName attribute, but FetchXML/Web API filters on it
    // require the numeric ObjectTypeCode rather than the entity logical name.
    const metadata = await api().getEntityMetadata(bpf.uniquename, true, ["ObjectTypeCode"]);
    const objectTypeCode = metadata.ObjectTypeCode;
    if (objectTypeCode === undefined || objectTypeCode === null) {
        throw new Error(`Could not resolve the object type code for "${bpf.uniquename}".`);
    }

    // No "type" filter here: the original plugin (FormXml.cs) only filters by objecttypecode,
    // relying on the BPF's private entity having exactly one form regardless of its form type.
    const fetchXml = `
        <fetch>
          <entity name="systemform">
            <attribute name="formid" />
            <attribute name="formxml" />
            <filter type="and">
              <condition attribute="objecttypecode" operator="eq" value="${escapeXmlAttr(String(objectTypeCode))}" />
            </filter>
          </entity>
        </fetch>`;

    const result = await api().fetchXmlQuery(fetchXml);
    if (result.value.length === 0) {
        throw new Error(`No Business Process Flow form was found for "${bpf.name}".`);
    }

    const record = result.value[0];
    return { formId: String(record.formid ?? ""), formXml: String(record.formxml ?? "") };
}

/** Loads the display name of an entity, for labeling fields in the stage/field list. */
export async function loadEntityDisplayName(entityLogicalName: string): Promise<string> {
    const metadata = await api().getEntityMetadata(entityLogicalName, true, ["DisplayName"]);
    return metadata.DisplayName?.LocalizedLabels?.[0]?.Label ?? entityLogicalName;
}

/** Loads attribute metadata for the BPF's primary entity, used for PCF-compatibility filtering. */
export async function loadEntityAttributes(entityLogicalName: string): Promise<AttributeInfo[]> {
    const response = await api().getEntityRelatedMetadata(entityLogicalName, "Attributes", [
        "LogicalName",
        "DisplayName",
        "AttributeType",
    ]);

    return (response.value as Array<Record<string, any>>)
        .filter((a) => a.AttributeType)
        .map((a): AttributeInfo => ({
            logicalName: a.LogicalName,
            displayName: a.DisplayName?.UserLocalizedLabel?.Label ?? a.DisplayName?.LocalizedLabels?.[0]?.Label ?? a.LogicalName,
            attributeType: a.AttributeType,
        }));
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

        controls.push({
            id: String(record.customcontrolid ?? ""),
            name,
            compatibleDataTypes,
            parameters: parsePcfManifestParameters(String(record.manifest ?? "")),
        });
    }

    return controls;
}

/**
 * Filters the registered PCF controls to the ones compatible with a Dataverse attribute type.
 *
 * @returns An empty array if `attributeType` has no known PCF-type mapping, rather than all
 * controls or an error.
 */
export function getCompatiblePcfControls(attributeType: string, controls: PcfControl[]): PcfControl[] {
    const compatibleTypes = ATTRIBUTE_TYPE_TO_PCF_TYPES[attributeType] ?? [];
    if (compatibleTypes.length === 0) return [];
    return controls.filter((c) => c.compatibleDataTypes.some((t) => compatibleTypes.includes(t)));
}

/** Saves the modified form XML back to the BPF's systemform record (does not publish). */
export async function saveBpfFormXml(formId: string, formXml: string): Promise<void> {
    await api().update("systemform", formId, { formxml: formXml });
}

/** Publishes customizations for the BPF's own entity so the changes take effect. */
export async function publishBpf(bpf: BpfProcess): Promise<void> {
    await api().publishCustomizations(bpf.uniquename);
}

/** Loads every visible, non-patch solution in the connected environment, for the "Solutions &
 * Publishers" filters. Dataverse's own auto-created default solutions (e.g. "Default Solution")
 * are hidden (`isvisible = 0`) and excluded, since they aren't a meaningful choice for scoping a
 * user's own BPFs/PCF controls; patches (`solutiontype = 2`) are excluded too, since they layer on
 * top of their parent solution rather than being a scoping choice of their own. */
export async function loadSolutions(): Promise<SolutionInfo[]> {
    const fetchXml = `
        <fetch>
          <entity name="solution">
            <attribute name="solutionid" />
            <attribute name="friendlyname" />
            <attribute name="uniquename" />
            <attribute name="version" />
            <attribute name="description" />
            <filter type="and">
              <condition attribute="isvisible" operator="eq" value="1" />
              <condition attribute="solutiontype" operator="ne" value="2" />
            </filter>
            <order attribute="friendlyname" />
          </entity>
        </fetch>`;

    const result = await api().fetchXmlQuery(fetchXml);
    return result.value.map((r) => ({
        solutionid: String(r.solutionid ?? ""),
        friendlyname: String(r.friendlyname ?? ""),
        uniquename: String(r.uniquename ?? ""),
        version: String(r.version ?? ""),
        description: String(r.description ?? ""),
    }));
}

/** Loads every publisher in the connected environment, for the "Solutions & Publishers" filters. */
export async function loadPublishers(): Promise<PublisherInfo[]> {
    const fetchXml = `
        <fetch>
          <entity name="publisher">
            <attribute name="publisherid" />
            <attribute name="friendlyname" />
            <attribute name="uniquename" />
            <attribute name="customizationprefix" />
            <attribute name="description" />
            <order attribute="friendlyname" />
          </entity>
        </fetch>`;

    const result = await api().fetchXmlQuery(fetchXml);
    return result.value.map((r) => ({
        publisherid: String(r.publisherid ?? ""),
        friendlyname: String(r.friendlyname ?? ""),
        uniquename: String(r.uniquename ?? ""),
        customizationprefix: String(r.customizationprefix ?? ""),
        description: String(r.description ?? ""),
    }));
}
