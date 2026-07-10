/**
 * Barrel export for the PPTB/DOM-agnostic services layer.
 *
 * @remarks
 * Framework-free by design — no React or DOM-UI imports, only `window.dataverseAPI` calls and
 * `DOMParser`/`XMLSerializer`. Re-exports, in dependency order:
 * - `types` — shared interfaces (`FieldInfo`, `PcfControl`, `AttributeInfo`, ...) and stage-color helpers.
 * - `pcfManifest` — parses a `customcontrol.manifest` XML string into PCF parameter definitions.
 * - `pcfClientJson` — parses a `customcontrol.clientjson` string into PCF parameter definitions and
 *   control-level metadata (virtual/standard, manifest version).
 * - `formxml` — BPF form XML parsing and `customControl` element mutation.
 * - `dataverse` — Dataverse queries (workflow/BPF, systemform, customcontrol, entity metadata).
 * - `metadata` — full entity + attribute metadata queries (LogicalName, DisplayName, ObjectTypeCode,
 *   AttributeType, RequiredLevel, MetadataId, Description), separate from `dataverse`'s trimmed
 *   `loadEntityAttributes`/`loadEntityDisplayName` used for PCF-compatibility filtering.
 */
export * from "../types";
export * from "./pcfManifest";
export * from "./pcfClientJson";
export * from "./formxml";
export * from "./dataverseservice/DataverseService";
export * from "./metadataservice/MetadataService";
