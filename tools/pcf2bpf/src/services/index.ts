/**
 * Barrel export for the PPTB/DOM-agnostic services layer.
 *
 * @remarks
 * Framework-free by design — no React or DOM-UI imports, only `window.dataverseAPI` calls and
 * `DOMParser`/`XMLSerializer`. Re-exports, in dependency order:
 * - `types` — shared interfaces (`FieldInfo`, `PcfControl`, `AttributeInfo`, ...) and stage-color helpers.
 * - `formxml` — BPF form XML parsing and `customControl` element mutation.
 * - `dataverse` — Dataverse queries (workflow/BPF, systemform, entity metadata).
 * - `metadata` — full entity + attribute metadata queries (LogicalName, DisplayName, ObjectTypeCode,
 *   AttributeType, RequiredLevel, MetadataId, Description), separate from `dataverse`'s trimmed
 *   `loadEntityAttributes`/`loadEntityDisplayName` used for PCF-compatibility filtering.
 * - `pcfservice` — parses `customcontrol.manifest`/`clientjson` into PCF parameter definitions and
 *   control-level metadata (virtual/standard, manifest version), and loads registered PCF controls.
 */
export * from "../types";
export * from "./formxml";
export * from "./dataverseservice/DataverseService";
export * from "./metadataservice/MetadataService";
export * from "./pcfservice/PcfService";
