# PCF2BPF

A Power Platform Tool Box (PPTB) tool to manage PCF (PowerApps Component Framework) controls on
Business Process Flow (BPF) fields, per form factor (Web / Phone / Tablet), without hand-editing form XML.

This is a port of [Carfup's XTBPlugins.PCF2BPF](https://github.com/carfup/XTBPlugins.PCF2BPF) XrmToolBox
plugin, reimplemented with React, TypeScript, and Fluent UI v9 (`@fluentui/react-components`) against the
PPTB `toolboxAPI` and `dataverseAPI`, following the same "full rewrite" porting strategy as PPTB's own
[fetchxmlbuilder-sample](https://github.com/PowerPlatformToolBox/sample-tools/tree/main/ported-tool/fetchxmlbuilder-sample)
and [react-sample](https://github.com/PowerPlatformToolBox/sample-tools/tree/main/new/react-sample).

## Features

- Load the Business Process Flows in the connected environment.
- Browse a BPF's stages and fields, shown as colored stage bands (matching the BPF's own stage colors in
  Dynamics 365).
- Select a field to see which registered PCF controls are compatible with its data type.
- Add, edit, or remove a PCF control on a field, independently per form factor (Web, Phone, Tablet).
- Copy a field's PCF configuration from one form factor to another.
- Configure a PCF control's non-bound manifest parameters via a generated form.
- Preview the form XML before committing, as a side-by-side Before/After comparison on a dedicated
  "Xml Details" tab.
- Save the form and publish the BPF's entity in one step ("Update and Publish").

## Not implemented (compared to the original XrmToolBox plugin)

- Binding a parameter to another field (only static values are supported).
- Localized (multi-language) parameter display names — the manifest's `display-name-key` is shown as-is.

These are intentionally out of scope for this first port, matching how PPTB's own sample ported tools scope
down XTB plugins to their core workflow.

## Project structure

```
pcf2bpf/
├── package.json
├── tsconfig.json / tsconfig.node.json
├── vite.config.ts
├── index.html
├── public/
│   └── icon/pcf2bpf-icon.svg
└── src/
    ├── main.tsx              # React entry point, FluentProvider + theme detection
    ├── App.tsx               # Top-level state and orchestration
    ├── index.css
    ├── hooks/
    │   └── useConnection.ts  # Active-connection polling hook
    ├── components/
    │   ├── BpfSelector.tsx
    │   ├── StagesFields.tsx           # Colored stage bands + field list
    │   ├── PcfConfigPanel.tsx         # Form-factor picker, PCF dropdown, parameters
    │   ├── CopyFormFactorPanel.tsx    # Copy a field's PCF config between form factors
    │   ├── FormXmlPanel.tsx
    │   └── Footer.tsx
    └── lib/
        ├── dataverse.ts      # Dataverse queries (workflow, systemform, customcontrol, metadata)
        ├── formxml.ts        # BPF form XML parsing + customControl XML manipulation
        ├── pcfManifest.ts    # customcontrol.manifest XML -> parameter definitions
        └── types.ts          # Shared TypeScript interfaces
```

`src/lib` has no dependency on React or the DOM UI — it only uses `DOMParser`/`XMLSerializer` and
`window.dataverseAPI`, so it's reused as-is from the original vanilla-TS implementation.

## Building

Prerequisites: Node.js 18+.

```bash
npm install
npm run dev        # Vite dev server, for iterating in a regular browser tab
npm run build       # type-check + bundle src/ to dist/ (single IIFE, per PPTB's loading constraints)
npm run watch        # rebuild on change
```

## Testing locally in PPTB

1. Build the tool (see above).
2. In Power Platform Tool Box, enable the Debug Menu in Settings.
3. Debug section → Browse → select this tool's directory (or the `dist` folder, depending on your PPTB
   version).
4. Connect to a Dataverse environment, then close/reopen the tool tab after each rebuild to reload changes.

## How it works

- **Business Process Flows** are `workflow` records with `category = 4`.
- A BPF's own form is the sole `systemform` record whose `objecttypecode` matches the BPF's private entity
  (the entity named after the BPF's `uniquename`). Since `objecttypecode` filters need the numeric
  `ObjectTypeCode` rather than the logical name, that entity's metadata is resolved first.
- Registered PCF controls are `customcontrol` records; `compatibledatatypes` lists the manifest types they
  support, and `manifest` is parsed for the control's configurable `<property>` parameters.
- A field's PCF assignment lives in the form XML under
  `controlDescriptions/controlDescription[@forControl]/customControl[@formFactor]`, mirroring the structure
  used by the original XTB plugin's `FormAttribute.cs`.
- The parsed form XML is held in a `useRef<XMLDocument>` in `App.tsx` (mutated in place by `lib/formxml.ts`,
  same as the original plugin mutates its in-memory `XmlDocument`) alongside a `docVersion` counter state
  that's bumped after every mutation to trigger re-renders, since React won't re-render on an in-place
  mutation of an object it already holds a reference to.

Since this logic was reverse-engineered from the original plugin's source rather than from a live comparison
against Microsoft's official form-customization schema, validate the generated XML in a non-production
environment before relying on it.

## License

GPL-2.0 — see the repository [LICENSE](../../LICENSE).
