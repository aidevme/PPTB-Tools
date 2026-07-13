import type { FieldInfo, FormFactor, PcfAssignment, PcfControl, StageInfo } from "../types";

/**
 * Parsing and editing of Business Process Flow form XML.
 *
 * Reimplements the XML manipulation from Carfup's XTBPlugins.PCF2BPF
 * (`AppCode/FormAttribute.cs`) against the browser DOM instead of .NET's XmlDocument.
 * A field's PCF assignment lives under:
 *
 * ```xml
 * <controlDescriptions>
 *   <controlDescription forControl="{control-guid}">
 *     <customControl id="{default-classid}">
 *       <parameters><datafieldname>fieldname</datafieldname></parameters>
 *     </customControl>
 *     <customControl name="publisher.Namespace.Control" formFactor="0">
 *       <parameters><paramName static="true" type="...">value</paramName></parameters>
 *     </customControl>
 *   </controlDescription>
 * </controlDescriptions>
 * ```
 */

/** Parses a BPF's `formxml` string into a mutable {@link XMLDocument}. */
export function parseFormXml(formXml: string): XMLDocument {
    const doc = new DOMParser().parseFromString(formXml, "application/xml");
    if (doc.querySelector("parsererror")) {
        throw new Error("Failed to parse Business Process Flow form XML.");
    }
    return doc;
}

/** Serializes a form XML document back to a string, e.g. for saving or previewing. */
export function serializeFormXml(doc: XMLDocument): string {
    return new XMLSerializer().serializeToString(doc);
}

/** Reads the BPF's stages from its `<tabs><tab>` nodes, in document order. */
export function getStages(doc: XMLDocument): StageInfo[] {
    return Array.from(doc.querySelectorAll("tabs > tab")).map((tab, index) => ({
        id: tab.getAttribute("id") ?? `stage-${index}`,
        name:
            tab.querySelector("labels > label")?.getAttribute("description") ??
            tab.getAttribute("name") ??
            `Stage ${index + 1}`,
    }));
}

/**
 * Extracts the logical name of the entity a field belongs to from its `<control>` node's
 * `relationship` attribute, e.g. `"lk_leadtoopportunitysalesprocess_leadid"` → `"lead"`. Dataverse
 * names the relationship between a BPF's private entity and a real business entity
 * `lk_{bpfUniqueName}_{entityLogicalName}id` — the entity is the last underscore-separated segment
 * with its trailing `id` (the standard Dataverse lookup-attribute suffix) removed.
 *
 * Multi-entity BPFs (e.g. a Lead → Opportunity sales process) have fields from different entities;
 * this is what lets `getFieldsForStage` resolve each field's own entity instead of assuming the
 * BPF's single `primaryentity` for every field. Returns `null` if `relationship` is absent (e.g. a
 * single-entity BPF may omit it) or doesn't end in `id`, so callers should fall back accordingly
 * rather than treat it as an error.
 */
export function getFieldEntityLogicalName(relationship: string | null): string | null {
    if (!relationship) return null;
    const segments = relationship.split("_");
    const last = segments[segments.length - 1];
    if (!/id$/i.test(last)) return null;
    const entityLogicalName = last.replace(/id$/i, "");
    return entityLogicalName || null;
}

/**
 * Reads the data fields on one stage, from its `<cell><control datafieldname="...">` nodes.
 * `fallbackEntityLogicalName` (the BPF's own `primaryentity`) is used for any field whose
 * `relationship` attribute doesn't resolve to an entity via `getFieldEntityLogicalName`.
 */
export function getFieldsForStage(doc: XMLDocument, stageId: string, fallbackEntityLogicalName: string): FieldInfo[] {
    const tab = Array.from(doc.querySelectorAll("tabs > tab")).find((t) => t.getAttribute("id") === stageId);
    if (!tab) return [];

    return Array.from(tab.querySelectorAll("cell > control[datafieldname]"))
        .map((control): Omit<FieldInfo, "sequence"> => ({
            controlId: control.getAttribute("id") ?? "",
            datafieldname: control.getAttribute("datafieldname") ?? "",
            label:
                control.closest("cell")?.querySelector("labels > label")?.getAttribute("description") ??
                control.getAttribute("datafieldname") ??
                "",
            classId: control.getAttribute("classid"),
            stageId,
            required: control.getAttribute("isrequired") === "true",
            entityLogicalName: getFieldEntityLogicalName(control.getAttribute("relationship")) ?? fallbackEntityLogicalName,
        }))
        .filter((field) => field.controlId && field.datafieldname)
        // Numbered after filtering, so this reflects the field's position among the valid fields
        // actually shown to the user, not its raw position in the form XML (which may include
        // malformed <control> nodes dropped by the filter above).
        .map((field, index) => ({ ...field, sequence: index + 1 }));
}

function getControlDescriptions(doc: XMLDocument): Element | null {
    return doc.querySelector("form > controlDescriptions");
}

function getOrCreateControlDescriptions(doc: XMLDocument): Element {
    let node = getControlDescriptions(doc);
    if (!node) {
        node = doc.createElement("controlDescriptions");
        doc.documentElement.appendChild(node);
    }
    return node;
}

function findControlDescription(doc: XMLDocument, controlId: string): Element | null {
    const container = getControlDescriptions(doc);
    if (!container) return null;
    return (
        Array.from(container.querySelectorAll("controlDescription")).find(
            (n) => n.getAttribute("forControl") === controlId,
        ) ?? null
    );
}

function getOrCreateControlDescription(doc: XMLDocument, controlId: string): Element {
    const container = getOrCreateControlDescriptions(doc);
    let node = findControlDescription(doc, controlId);
    if (!node) {
        node = doc.createElement("controlDescription");
        node.setAttribute("forControl", controlId);
        container.appendChild(node);
    }
    return node;
}

function findFormFactorNode(desc: Element, formFactor: FormFactor): Element | null {
    return (
        Array.from(desc.querySelectorAll("customControl[formFactor]")).find(
            (n) => n.getAttribute("formFactor") === String(formFactor),
        ) ?? null
    );
}

/** Reads the current PCF assignment for a field + form factor, if one exists. */
export function getExistingCustomControl(
    doc: XMLDocument,
    controlId: string,
    formFactor: FormFactor,
): PcfAssignment | null {
    const desc = findControlDescription(doc, controlId);
    if (!desc) return null;

    const node = findFormFactorNode(desc, formFactor);
    if (!node) return null;

    const parameters: Record<string, string> = {};
    node.querySelectorAll("parameters > *").forEach((p) => {
        parameters[p.tagName] = p.textContent ?? "";
    });

    return { name: node.getAttribute("name") ?? "", parameters };
}

/** Adds or replaces the PCF control assigned to a field for one form factor. */
export function setCustomControl(
    doc: XMLDocument,
    field: FieldInfo,
    pcf: PcfControl,
    formFactor: FormFactor,
    parameterValues: Record<string, string>,
): void {
    const desc = getOrCreateControlDescription(doc, field.controlId);

    if (!desc.querySelector("customControl[id]")) {
        const base = doc.createElement("customControl");
        base.setAttribute("id", field.classId ?? "");
        const baseParams = doc.createElement("parameters");
        const df = doc.createElement("datafieldname");
        df.textContent = field.datafieldname;
        baseParams.appendChild(df);
        base.appendChild(baseParams);
        desc.appendChild(base);
    }

    const existing = findFormFactorNode(desc, formFactor);
    if (existing) desc.removeChild(existing);

    const node = doc.createElement("customControl");
    node.setAttribute("name", pcf.parameters[0]?.controlName ?? "");
    node.setAttribute("formFactor", String(formFactor));

    const params = doc.createElement("parameters");
    for (const param of pcf.parameters) {
        if (param.usage === "bound") continue;
        const value = parameterValues[param.name];
        if (value === undefined || value === "") continue;

        const el = doc.createElement(param.name);
        el.setAttribute("static", "true");
        if (param.ofType) el.setAttribute("type", param.ofType);
        el.textContent = value;
        params.appendChild(el);
    }
    node.appendChild(params);
    desc.appendChild(node);
}

/** Removes the PCF control assigned to a field for one form factor. */
export function removeCustomControl(doc: XMLDocument, controlId: string, formFactor: FormFactor): void {
    const desc = findControlDescription(doc, controlId);
    if (!desc) return;

    const node = findFormFactorNode(desc, formFactor);
    if (node) desc.removeChild(node);

    if (desc.querySelectorAll("customControl[formFactor]").length === 0) {
        desc.parentElement?.removeChild(desc);
    }
}

/** Whether a field has a PCF control assigned on at least one form factor. */
export function hasAnyCustomControl(doc: XMLDocument, controlId: string): boolean {
    const desc = findControlDescription(doc, controlId);
    return !!desc && desc.querySelectorAll("customControl[formFactor]").length > 0;
}

/**
 * Clones a field's PCF assignment (control + parameter values) from one form factor to another,
 * overwriting whatever was on the target form factor.
 */
export function copyCustomControl(
    doc: XMLDocument,
    controlId: string,
    fromFormFactor: FormFactor,
    toFormFactor: FormFactor,
): boolean {
    const desc = findControlDescription(doc, controlId);
    if (!desc) return false;

    const source = findFormFactorNode(desc, fromFormFactor);
    if (!source) return false;

    const existingTarget = findFormFactorNode(desc, toFormFactor);
    if (existingTarget) desc.removeChild(existingTarget);

    const clone = source.cloneNode(true) as Element;
    clone.setAttribute("formFactor", String(toFormFactor));
    desc.appendChild(clone);
    return true;
}
