# Contributing

<!-- cspell:ignore fixHtmlForPPTB -->

This is the contributor guide for the Dataverse Early-Bound TypeScript Generator. The tool lives in
[`tools/dataverse-early-bound-typescript-generator/`](https://github.com/aidevme/PPTB-Tools/tree/main/tools/dataverse-early-bound-typescript-generator),
a self-contained package with its own `package.json`, build and docs; there is no repo-wide build or test command.
For commit message and pull request conventions, see the repository's
[CONTRIBUTING.md](https://github.com/aidevme/PPTB-Tools/blob/main/CONTRIBUTING.md).

## Prerequisites

- Node.js and npm.
- [Power Platform ToolBox](https://www.powerplatformtoolbox.com/) (PPTB) and a Dataverse environment, to try the
  tool for real.

## Commands

Run from `tools/dataverse-early-bound-typescript-generator/`:

```bash
npm install
npm run dev      # Vite dev server; PPTB APIs are absent, so the UI shows a warning
npm run build    # tsc typecheck + vite build -> dist/ (single IIFE bundle)
npm run watch    # rebuild dist/ on change
npm test         # vitest suite
```

`npm run build` runs `tsc`, so it is the correctness check to run after changes; run `npm test` too. There is no
lint script.

## Dev server versus PPTB

`npm run dev` is for iterating on the UI in a regular browser tab. `window.dataverseAPI` and `window.toolboxAPI`
exist only inside PPTB, so in the browser the tool shows a warning and can't connect. Anything that touches a
connection or the file system has to be tried inside PPTB.

## Testing inside PPTB

1. Build the tool (`npm run build`).
2. In PPTB, turn on the Debug Menu in Settings.
3. Use **Debug → Browse** and select the tool's directory (or `dist`).
4. Connect to a Dataverse environment.
5. Reopen the tool tab after each rebuild.

Use a throwaway test project, never one whose generated files you can't regenerate. [Testing](./testing.md) lists
the checks that have been run live and the ones still to do.

## The build constraint

PPTB loads tools from a local folder (often `file://` or an iframe `srcdoc`), where
`<script type="module">` can fail to run. So `vite.config.ts` has a custom `fixHtmlForPPTB` plugin that strips
`type="module"` and `crossorigin` from the built HTML and moves the script tags to the end of `<body>`, and the
Rollup output is forced to `iife` with `inlineDynamicImports: true` so the app ships as one script.

Don't reintroduce code splitting or ESM output. `npm run dev` would still work, but the tool would break inside
PPTB. Details: [Build and testing](../architecture/build-and-testing.md).

## Output must match dataverse-gen

The generator's output must match dataverse-gen's character for character, apart from the deliberate deviations
listed in the tool's
[README](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/README.md#deliberate-deviations-from-dataverse-gen-output).
The EJS templates are reimplemented as plain functions in `core/templates.ts`, because EJS's `new Function` is
blocked by the PPTB iframe's Content Security Policy. `test/generator.test.ts` compares the output with the real
CLI's output in `test/reference/`. If a change alters the output on purpose, update the reference files and list it
as a deviation in the README.

## Code organization

- `src/core/` is pure TypeScript: no PPTB, no I/O, no UI (`DOMParser` only for the CSDL). `src/services/` holds
  the PPTB adapters and file planning. The state lives in hooks in `src/hooks/`, which
  `src/components/apps/App.tsx` wires together; the other component folders are presentational and receive data and
  callbacks as props.
- Each folder has an `index.ts` barrel (`components`, `hooks`, `services`, `core`, `types`). Add new exports
  there. Inside `services/`, files import each other directly rather than through the barrel, to avoid cycles.

## Where to go next

- [Architecture](../architecture/): layers, data flow, core, services, app state, build and testing
- [Components](../components/): the UI components and their conventions
- [Testing](./testing.md): unit tests and live PPTB checks
- [Design history](./design-history.md): the original planning document
