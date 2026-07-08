/**
 * Barrel export for the PPTB/DOM-agnostic services layer.
 *
 * @remarks
 * Framework-free by design — no React or DOM-UI imports, only `window.dataverseAPI` calls and
 * `DOMParser`/`XMLSerializer`. Re-exports, in dependency order:
 * - `types` — shared interfaces (`FieldInfo`, `PcfControl`, `AttributeInfo`, ...) and stage-color helpers.
 * - `pcfManifest` — parses a `customcontrol.manifest` XML string into PCF parameter definitions.
 * - `formxml` — BPF form XML parsing and `customControl` element mutation.
 * - `dataverse` — Dataverse queries (workflow/BPF, systemform, customcontrol, entity metadata).
 */
export * from "../types";
export * from "./pcfManifest";
export * from "./formxml";
export * from "./dataverse";
