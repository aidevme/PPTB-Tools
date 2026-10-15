# Build: "Some chunks are larger than 500 kB" warning

<!-- cspell:ignore Bmnl -->

Status: **to do**. Tool: [Dataverse Early-Bound TypeScript Generator](../pptb-tools/dataverse-early-bound-typescript-generator/index.md).

## The warning

`npm run build` in `tools/dataverse-early-bound-typescript-generator` (tool 1.0.0, Vite 7.3.7) succeeds, but prints:

```text
> dataverse-early-bound-typescript-generator@1.0.0 build
> tsc && vite build

vite v7.3.7 building client environment for production...
✓ 2263 modules transformed.
dist/index.html                  0.32 kB │ gzip:   0.24 kB
dist/assets/index-BmnlRfd7.js  965.92 kB │ gzip: 274.50 kB

(!) Some chunks are larger than 500 kB after minification. Consider:
- Using dynamic import() to code-split the application
- Use build.rollupOptions.output.manualChunks to improve chunking: https://rollupjs.org/configuration-options/#output-manualchunks
- Adjust chunk size limit for this warning via build.chunkSizeWarningLimit.
```

It's a **warning, not an error**: the build output is complete and the tool works. The bundle has grown from
926 kB to 966 kB over recent changes (the Settings panel redesign, paging, new settings).

## Root cause

1. **The tool ships as one script on purpose.** PPTB loads tools from a local folder (often `file://` or an iframe
   `srcdoc`), where ES modules and split chunks can fail to load. So `vite.config.ts` forces Rollup to a single
   IIFE (`format: 'iife'`, `inlineDynamicImports: true`), and the custom `fixHtmlForPPTB` plugin strips
   `type="module"`. Everything, including React and Fluent UI, ends up in one file.
2. **Vite warns about any chunk over 500 kB minified** (`build.chunkSizeWarningLimit`, default 500). That default
   assumes a website downloading code over the network, where a large chunk delays the first page. A single bundle
   for a React + Fluent UI v9 app is always well over it.

What's in the bundle (measured from a source-map build on 2026-10-14):

| Part | Minified | Share | Notes |
| --- | --- | --- | --- |
| Fluent UI v9 (components, Griffel, tabster, tokens, floating-ui) | 551 kB | 58% | Largest pieces: tabster 71 kB, tokens 34 kB, tabs 29 kB, card 28 kB, button 24 kB, table 20 kB, spin button 19 kB, dialog 18 kB |
| React + ReactDOM | 143 kB | 15% | Production build |
| The tool's own code (`src/`) | 142 kB | 15% | Generator, services, UI |
| prism-react-renderer | 84 kB | 9% | Syntax highlighting for the file viewer; bundles Prism with many languages, though the tool only highlights TypeScript |
| @fluentui/react-icons | 22 kB | 2% | Tree-shaken correctly (named imports) |
| Total | 966 kB | | 275 kB gzipped |

So the size comes from the UI framework the tool is built on, not from a mistake such as importing a whole icon
set. And the main reason for the warning doesn't apply: PPTB reads the file **from local disk**, not over the
network.

## Options

### Don't do: code splitting or manual chunks

Vite's first two suggestions, `import()` and `build.rollupOptions.output.manualChunks`, would produce several
files. That breaks loading inside PPTB, even though `npm run dev` would still work (see the build constraint in
CLAUDE.md). Don't use them.

### 1. Raise the warning limit, with a reason (recommended now)

Accept the single bundle and set the limit just above today's size, so the warning only reappears if the bundle
grows noticeably (for example after adding a large dependency). In `vite.config.ts`, under `build`:

```ts
build: {
    // PPTB needs one IIFE script (no code splitting), so a ~1 MB bundle of React + Fluent UI v9 is expected; it's
    // read from local disk, not downloaded. The limit catches unexpected growth: raise it deliberately.
    chunkSizeWarningLimit: 1100,
    // …existing rollupOptions
},
```

- **Effort:** one line. **Risk:** none; output is unchanged.
- **Review it** whenever a build passes 1,100 kB: check what was added before raising it.

### 2. Make the bundle smaller (optional)

Worth doing only if load time in PPTB becomes noticeable; none has been reported.

| Change | Estimated saving | Effort | Notes |
| --- | --- | --- | --- |
| Replace prism-react-renderer with a small TypeScript-only highlighter (or Prism core plus the TypeScript grammar only) | Up to ~70 kB (7%) | Medium | prism-react-renderer v2 bundles its own Prism with a fixed set of languages, so they can't be dropped by configuration. The file viewer only needs TypeScript and JSON. |
| Show plain text, without highlighting, for very large files | Small | Low | `CodeViewer` already skips highlighting above 300,000 characters; affects speed more than size |
| Trim Fluent UI components used in only one place | Small (10–30 kB each) | Medium–high | Each component used today has a purpose (`Card`, `TabList`, `SpinButton`, `Table`, `Dialog`, `Drawer`); swapping them for custom markup would cost consistency and accessibility |
| Upgrade Fluent UI v9 and Vite regularly | Varies | Low | Newer releases sometimes reduce size; check the effect on each upgrade |

React and the core of Fluent UI (Griffel, tabster, tokens) can't be removed without changing the UI framework,
which isn't worthwhile.

### 3. Watch the size in CI (optional)

With option 1 in place, the build log warns when the bundle passes the limit. For a stricter check, add a step to
`.github/workflows/dataverse-early-bound-typescript-generator-build.yml` after the build that fails (or adds a
warning annotation) when `dist/assets/*.js` passes a set size.

## Recommendation

1. **Now:** option 1, setting `chunkSizeWarningLimit: 1100` with the comment above.
2. **Later, if wanted:** replace prism-react-renderer (option 2, first row), the only sizeable saving that doesn't
   change the UI.
3. **Never:** code splitting or `manualChunks`.

## How the sizes were measured

```bash
# From tools/dataverse-early-bound-typescript-generator, into a temporary folder (dist/ is left alone)
npx vite build --sourcemap --outDir <temp-folder> --emptyOutDir
```

The minified bytes were then attributed to packages through the source map (with `source-map-js`, already in
`node_modules`). For an interactive view, `npx vite-bundle-visualizer` produces a treemap of the same data.

## Checklist

- [ ] Set `chunkSizeWarningLimit` with the comment in `vite.config.ts`
- [ ] `npm run build` shows no size warning
- [ ] (Optional) Replace prism-react-renderer; re-measure
- [ ] (Optional) Add a bundle-size check to the build workflow
