# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository overview

This repo hosts individual tools that plug into **Power Platform ToolBox (PPTB)**, following the same
model as XrmToolBox plugins: each tool under `tools/<tool-name>/` is a self-contained add-in for working
with Microsoft Dataverse / Power Platform. Each tool has its own `package.json`, build, and docs — there is
no repo-wide build/test command. Docs for each tool live in `docs/pptb-tools/<tool-name>/index.md` (user-facing) plus
a `tools/<tool-name>/README.md` (implementation details); `README.md` at the repo root indexes all tools.

New tools are frequently **ports of existing XrmToolBox plugins** (see
`.github/ISSUE_TEMPLATE/tool_port_request.yml`), reimplemented against PPTB's APIs rather than copied
wholesale — check the tool's README for which original plugin it's based on and what was intentionally
left out of scope.

## Agent pipeline

This repo defines project subagents (`architect`, `developer`, `tester`, `documenter`, `code-reviewer`,
`commit-writer`) in `.claude/agents/*.md` for a plan → implement → verify → document → review → commit
workflow. See `docs/agents/index.md` for what each one covers and its boundaries — don't duplicate that
here.

## Shared tool conventions

Every tool is React + TypeScript + Fluent UI v9 (`@fluentui/react-components`), built with Vite. Run these
from the tool's own folder:

```bash
npm install
npm run dev      # Vite dev server, for iterating in a regular browser tab (PPTB APIs are absent)
npm run build    # tsc typecheck + vite build -> dist/ (single IIFE bundle)
npm run watch    # rebuild dist/ on change
npm test         # only where the tool's package.json defines it
```

`npm run build` (which runs `tsc`) is the correctness check to run after changes; also run `npm test` when
the tool has one. There is no lint script.

To test inside PPTB itself: build, then in PPTB enable the Debug Menu in Settings, use Debug → Browse to
point at the tool's directory (or `dist`), connect to a Dataverse environment, and reopen the tool tab
after each rebuild.

### Build constraint that shapes `vite.config.ts`

PPTB loads tools from a local folder (often `file://` or an iframe `srcdoc`), where `<script type="module">`
can fail to execute. Each tool's `vite.config.ts` has a custom `fixHtmlForPPTB` plugin that strips
`type="module"`/`crossorigin` from the built HTML and moves script tags to the end of `<body>`; the Rollup
output format is forced to `iife` with `inlineDynamicImports: true` so the whole app ships as one script.
Don't reintroduce code-splitting or ESM output — it will break loading inside PPTB even though
`npm run dev` still works fine.

## Dataverse Early-Bound TypeScript Generator (`tools/dataverse-early-bound-typescript-generator/`)

Generates early-bound TypeScript types and metadata for Dataverse tables, actions and functions. A port of
Scott Durow's [dataverse-gen](https://github.com/scottdurow/dataverse-gen) CLI: its output works with
[dataverse-ify](https://github.com/scottdurow/dataverse-ify) and it shares the `.dataverse-gen.json`
project file. Docs: `docs/pptb-tools/dataverse-early-bound-typescript-generator/`.

```
src/
├── main.tsx / App.tsx  # theme + all top-level state and orchestration (no state management library)
├── core/               # pure TS: no PPTB, no I/O, no DOM-UI (DOMParser only for the CSDL)
├── services/           # PPTB adapters: dataverseAPI metadata, toolboxAPI file system, write planning
├── hooks/              # useConnection: polls window.toolboxAPI for the active connection
├── components/         # presentational; receive data/callbacks from App.tsx as props
└── types/
test/                   # vitest: dataverse-gen fixtures + the real CLI's reference output
```

Things that aren't obvious from a single file:

- **Output must match dataverse-gen byte for byte**, apart from the deliberate deviations listed in the
  tool's README. The EJS templates are reimplemented as plain functions in `core/templates.ts` (EJS's
  `new Function` is blocked by the PPTB iframe CSP), and `test/generator.test.ts` compares the output
  against `test/reference/`.
- **Each folder has an `index.ts` barrel** (`components`, `hooks`, `services`, `core`, `types`). Add new
  exports there. Inside `services/`, files import each other directly rather than through the barrel, to
  avoid cycles.
- **Private custom APIs aren't in `$metadata`.** They're still listed; their definitions are built from the
  `customapi` record and its `customapirequestparameters`.
- **Orphaned files are deleted only on opt-in.** They're reported by default; they're removed only when the
  user turns on *Delete orphaned files* and confirms the list. PPTB's file API has no delete, so deletion
  runs through a hidden PPTB terminal (`PptbFileSink.deleteFiles`), and `deleteOrphanedFiles` in
  `services/plan.ts` guards which paths reach it.
