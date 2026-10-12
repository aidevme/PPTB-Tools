# Build and testing

## Commands

Run from `tools/dataverse-early-bound-typescript-generator/`:

```bash
npm install
npm run dev      # Vite dev server; PPTB APIs are absent, so the UI shows a warning
npm run build    # tsc typecheck + vite build -> dist/
npm run watch    # rebuild dist/ on change
npm test         # vitest suite
```

## Single-script bundle

PPTB loads tools from a local folder, often over `file://` or in an iframe `srcdoc`, where
`<script type="module">` can fail to run. So `vite.config.ts`:

- outputs one IIFE script (`format: 'iife'`, `inlineDynamicImports: true`), with no code splitting
- uses a custom `fixHtmlForPPTB` plugin that strips `type="module"` and `crossorigin` from the built HTML and
  moves the script tags to the end of `<body>`

Don't reintroduce code splitting or ESM output. `npm run dev` would still work, but the tool would break
inside PPTB. For the same reason, dependencies must bundle without lazy loading or WebAssembly.

## Tests

The vitest suite runs in a jsdom environment, because the CSDL parser needs `DOMParser`. Test files are
`test/**/*.test.ts`.

| File | Covers |
| --- | --- |
| `generator.test.ts` | CSDL parsing, selection expansion, and generated output compared file by file with the real dataverse-gen CLI's output |
| `customApi.test.ts` | Private custom APIs missing from `$metadata`: listed, selectable, and generated from their definitions |
| `services.test.ts` | Path helpers, config round-trip, and write planning (statuses, casing reuse, first-time folder creation) |

Test data:

- `test/fixtures/` holds trimmed dataverse-gen test data: an EDMX document and entity metadata.
- `test/reference/` holds the real dataverse-gen CLI's output for those fixtures, with LF line endings.

When a change to the core alters generated output on purpose, the reference files need updating too, and the
change should be listed as a deliberate deviation in the tool's README.

## Continuous integration

`.github/workflows/dataverse-early-bound-typescript-generator-build.yml` runs on pushes and pull requests to
`main` that touch the tool. It runs `npm ci`, `npm test` and `npm run build`, then uploads `dist/` as a build
artifact. The repo-wide `build-tool.yml` workflow also builds every tool after CodeQL finishes.

## Testing inside PPTB

Build, enable the Debug Menu in PPTB's Settings, use Debug → Browse to load the tool's folder, connect to an
environment, and reopen the tool tab after each rebuild.
