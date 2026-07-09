import { parsePcfManifestParameters } from "./pcfManifest";
import { parsePcfClientJsonInfo } from "./pcfClientJson";
import type { AttributeInfo, BpfProcess, BpfScope, PcfControl, PublisherInfo, SolutionInfo } from "../types";

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

/**
 * Loads Business Process Flow definitions (`workflow` records with `category = 4`), optionally scoped
 * to one solution or one publisher's solutions via a `solutioncomponent` join (`componenttype = 29` is
 * the Workflow/BPF component type; see `docs/pcf2bpf/dataverse/solution-component.md`). Omit `scope`
 * to load every BPF in the environment, unfiltered.
 */
export async function loadBpfProcesses(scope?: BpfScope): Promise<BpfProcess[]> {
    const solutionFilter =
        scope && "solutionId" in scope
            ? `<condition attribute="solutionid" operator="eq" value="${escapeXmlAttr(scope.solutionId)}" />`
            : "";

    // A publisher can own several solutions, so this joins one level further than the solution-scoped
    // case; `distinct` below dedupes a BPF that ends up in more than one of that publisher's solutions.
    const publisherLink =
        scope && "publisherId" in scope
            ? `<link-entity name="solution" from="solutionid" to="solutionid" link-type="inner">
                 <filter type="and">
                   <condition attribute="publisherid" operator="eq" value="${escapeXmlAttr(scope.publisherId)}" />
                 </filter>
               </link-entity>`
            : "";

    const scopeLink = scope
        ? `<link-entity name="solutioncomponent" from="objectid" to="workflowid" link-type="inner">
             <filter type="and">
               <condition attribute="componenttype" operator="eq" value="29" />
               ${solutionFilter}
             </filter>
             ${publisherLink}
           </link-entity>`
        : "";

    const fetchXml = `
        <fetch${scope ? ' distinct="true"' : ""}>
          <entity name="workflow">
            <attribute name="workflowid" />
            <attribute name="name" />
            <attribute name="uniquename" />
            <attribute name="primaryentity" />
            <attribute name="xaml" />
            <filter type="and">
              <condition attribute="category" operator="eq" value="4" />
            </filter>
            ${scopeLink}
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
            <attribute name="clientjson" />
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

        const { isVirtual, version } = parsePcfClientJsonInfo(String(record.clientjson ?? ""));

        controls.push({
            id: String(record.customcontrolid ?? ""),
            name,
            compatibleDataTypes,
            parameters: parsePcfManifestParameters(String(record.manifest ?? "")),
            isVirtual,
            version,
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
              <condition attribute="ismanaged" operator="eq" value="0" />
            </filter>
            <order attribute="friendlyname" />
          </entity>
        </fetch>`;

    const result = await api().fetchXmlQuery(fetchXml);
    return result.value.map((r) => {
        const uniquename = String(r.uniquename ?? "");
        return {
            solutionid: String(r.solutionid ?? ""),
            friendlyname: String(r.friendlyname ?? ""),
            uniquename,
            version: String(r.version ?? ""),
            description: String(r.description ?? ""),
            isDefaultSolution: uniquename === "Default",
        };
    });
}

/** Loads the publishers of every visible solution in the connected environment, for the "Solutions &
 * Publishers" filters (equivalent to `GET solutions?$filter=isvisible eq true&$expand=publisherid(...)`,
 * but as a single FetchXML query joining `publisher` to `solution` instead of expanding a navigation
 * property). `distinct` dedupes publishers that own more than one visible solution. */
export async function loadPublishers(): Promise<PublisherInfo[]> {
    const fetchXml = `
        <fetch distinct="true">
          <entity name="publisher">
            <attribute name="publisherid" />
            <attribute name="friendlyname" />
            <attribute name="uniquename" />
            <attribute name="customizationprefix" />
            <attribute name="description" />
            <order attribute="friendlyname" />
            <link-entity name="solution" from="publisherid" to="publisherid" link-type="inner">
              <filter type="and">
                <condition attribute="isvisible" operator="eq" value="1" />
              </filter>
            </link-entity>
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
