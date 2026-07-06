# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository overview

This repo hosts individual tools that plug into **Power Platform ToolBox (PPTB)**, following the same
model as XrmToolBox plugins: each tool under `tools/<tool-name>/` is a self-contained add-in for working
with Microsoft Dataverse / Power Platform. Each tool has its own `package.json`, build, and docs — there is
no repo-wide build/test command. Docs for each tool live in `docs/<tool-name>/index.md` (user-facing) plus
a `tools/<tool-name>/README.md` (implementation details); `README.md` at the repo root indexes all tools.

New tools are frequently **ports of existing XrmToolBox plugins** (see
`.github/ISSUE_TEMPLATE/tool_port_request.yml`), reimplemented against PPTB's APIs rather than copied
wholesale — check the tool's README for which original plugin it's based on and what was intentionally
left out of scope.

## Agent pipeline

This repo defines project subagents (`architect`, `developer`, `tester`, `documenter`, `code-reviewer`) in
`.claude/agents/*.md` for a plan → implement → verify → document → review workflow. See
`docs/agents/index.md` for what each one covers and its boundaries — don't duplicate that here.

## PCF2BPF (`tools/pcf2bpf/`)

The only tool implemented so far. Lets users add/edit/remove PCF (PowerApps Component Framework) controls
on Business Process Flow (BPF) fields, per form factor (Web/Phone/Tablet), without hand-editing form XML.
Port of [Carfup's XTBPlugins.PCF2BPF](https://github.com/carfup/XTBPlugins.PCF2BPF), rewritten in React +
TypeScript + Fluent UI v9 (`@fluentui/react-components`).

### Commands (run from `tools/pcf2bpf/`)

```bash
npm install
npm run dev      # Vite dev server, for iterating in a regular browser tab
npm run build    # tsc typecheck + vite build -> dist/ (single IIFE bundle)
npm run watch    # rebuild dist/ on change
npm run preview  # preview the built dist/
```

There is no test suite or lint script configured for this tool; `npm run build` (which runs `tsc`) is the
correctness check to run after changes.

To test inside PPTB itself: build, then in PPTB enable the Debug Menu in Settings, use Debug → Browse to
point at this tool's directory (or `dist`), connect to a Dataverse environment, and reopen the tool tab
after each rebuild.

### Build constraint that shapes `vite.config.ts`

PPTB loads tools from a local folder (often `file://` or an iframe `srcdoc`), where `<script type="module">`
can fail to execute. The custom `fixHtmlForPPTB` Vite plugin in `vite.config.ts` strips `type="module"`/
`crossorigin` from the built HTML and moves script tags to the end of `<body>`; the Rollup output format is
forced to `iife` with `inlineDynamicImports: true` so the whole app ships as one script. Don't reintroduce
code-splitting or ESM output — it will break loading inside PPTB even though `npm run dev` still works fine.

### Architecture

```
src/
├── main.tsx      # FluentProvider + theme detection, entry point
├── App.tsx       # all top-level state + orchestration (no state management library)
├── hooks/
│   └── useConnection.ts   # polls window.toolboxAPI for the active Dataverse connection
├── components/             # presentational; receive data/callbacks from App.tsx as props
└── lib/                     # framework-free: no React/DOM-UI, only DOMParser/XMLSerializer + window.dataverseAPI
    ├── dataverse.ts   # Dataverse queries: workflow (BPF), systemform, customcontrol, entity metadata
    ├── formxml.ts     # BPF form XML parsing + customControl XML mutation
    ├── pcfManifest.ts # customcontrol.manifest XML -> parameter definitions
    └── types.ts       # shared TypeScript interfaces
```

Key domain facts (needed to make sense of `lib/dataverse.ts` and `lib/formxml.ts`):

- **Business Process Flows** are `workflow` records with `category = 4`.
- A BPF's form is the sole `systemform` record whose `objecttypecode` matches the BPF's private entity
  (named after the BPF's `uniquename`). Since `objecttypecode` filters need the numeric `ObjectTypeCode`
  rather than the logical name, that entity's metadata is resolved first.
- Registered PCF controls are `customcontrol` records; `compatibledatatypes` lists the manifest types they
  support, and `manifest` (XML) is parsed for the control's configurable `<property>` parameters.
- A field's PCF assignment lives in the form XML under
  `controlDescriptions/controlDescription[@forControl]/customControl[@formFactor]`, mirroring the
  original XTB plugin's `FormAttribute.cs`.

State management pattern in `App.tsx`: the parsed form XML document is held in a `useRef<XMLDocument>`
(mutated in place by `lib/formxml.ts` functions, matching how the original plugin mutates its in-memory
`XmlDocument`), alongside a `docVersion` counter state that's incremented after every mutation via the
`mutateDoc` helper. Since React won't re-render on an in-place mutation of an object it already holds a
reference to, anything derived from the doc (e.g. `existingAssignment`) must list `docVersion` — not the
doc itself — in its dependency array.

Because this was reverse-engineered from the original plugin's source rather than validated against
Microsoft's official form-customization schema, treat generated form XML as unverified in production
environments — see the "Known limitations" section of `docs/pcf2bpf/index.md` for what's intentionally
unsupported (copying config across form factors, binding parameters to fields, localized parameter names).
