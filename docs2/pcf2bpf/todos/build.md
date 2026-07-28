# Build warnings

`npm run build` (`tsc && vite build`) in `tools/pcf2bpf` currently prints two warnings. Neither breaks the
build; this doc records root cause and fix options so they can be addressed deliberately instead of by
guesswork.

## 1. "The CJS build of Vite's Node API is deprecated"

```
The CJS build of Vite's Node API is deprecated. See https://vite.dev/guide/troubleshooting.html#vite-cjs-node-api-deprecated for more details.
```

**Root cause.** This is about how `vite.config.ts` is *loaded*, not the build output. `package.json` has no
`"type": "module"`, so Node treats the package as CommonJS. Vite 5 transpiles `vite.config.ts` and, in a CJS
package, loads it via `require()`; the config's `import { defineConfig } from "vite"` then resolves to
Vite's **CJS Node API build**, which Vite 5 deprecated. That CJS build was **removed entirely in Vite 6**, so
on the current `^5.4.11` range the warning is cosmetic — nothing breaks — but a future major upgrade would
force a fix anyway. The `tsc` step is unaffected.

**Fix options (ranked):**

1. **Rename `vite.config.ts` → `vite.config.mts`.** Forces ESM loading of just the config file; zero blast
   radius on the rest of the package. Needs a follow-up update to `tsconfig.node.json`'s `include`.
2. **Add `"type": "module"` to `package.json`.** Vite's own documented fix. Looks safe for this package —
   `"main": "index.html"` is PPTB metadata rather than a JS entry point, scripts are only `tsc`/`vite`/`npm
   shrinkwrap`, and there are no other `.js` CJS files in the package — but should be spot-checked against
   how PPTB itself loads `package.json` before applying, in case any field is read as a Node entry point.
3. **Upgrade to Vite 6/7.** Removes the deprecated API entirely (ESM-only loader), but is a major-version
   migration that would need revalidating `fixHtmlForPPTB` and the forced IIFE output inside PPTB. Not
   worth doing solely for this warning.
4. **Do nothing.** Valid on Vite 5 — the warning is print-only with no output difference.

## 2. "Some chunks are larger than 500 kB after minification"

```
(!) Some chunks are larger than 500 kB after minification. Consider:
- Using dynamic import() to code-split the application
- Use build.rollupOptions.output.manualChunks to improve chunking
- Adjust chunk size limit for this warning via build.chunkSizeWarningLimit.
✓ built in ...
```
Actual output: `dist/assets/index-*.js  673.25 kB │ gzip: 186.20 kB`.

**Root cause.** Vite's `build.chunkSizeWarningLimit` defaults to 500 kB (minified, pre-gzip); the single
bundle is 673 kB (186 kB gzip), dominated by `@fluentui/react-components` + React 18 — inherent to a Fluent
UI v9 app. Both remedies the warning itself suggests are **structurally unavailable** here:

- `manualChunks` is rejected by Rollup when `inlineDynamicImports: true` is set, and IIFE output doesn't
  support multi-chunk builds at all.
- Dynamic `import()` code-splitting is explicitly disallowed by this repo's PPTB loading constraint — see
  the root `CLAUDE.md`'s note on `vite.config.ts`: PPTB can load tools from `file://` or an iframe `srcdoc`
  where `<script type="module">` can fail to execute, so output is forced to a single `iife` bundle with
  `inlineDynamicImports: true`. Reintroducing code-splitting/ESM output breaks loading inside PPTB even
  though `npm run dev` would still work fine.

**Is 673 kB actually a problem?** No — the tool loads once per PPTB session from local disk, not as a
public web app with per-request payload/caching concerns. The warning's underlying mental model doesn't
apply to this deployment target; it's noise here.

**Fix options (ranked, by compatibility with the single-IIFE constraint):**

1. **Raise `build.chunkSizeWarningLimit`** (e.g. to `1000`) in `vite.config.ts`, with a comment explaining
   why code-splitting isn't an option for this tool. Compatible; purely cosmetic, and honest — the tradeoff
   the warning is trying to flag (split for caching/lazy-load) is structurally impossible here anyway.
2. **Marginal bundle trimming.** Compatible but low yield: `@fluentui/react-icons` is imported via named
   barrel imports, but the package ships tree-shakeable ESM with `sideEffects: false`, so unused icons are
   already dropped from `dist` in production builds — the barrel mostly costs dev-server cold-start, not
   final bundle size. Switching `build.minify` to `terser` might shave a few percent at the cost of slower
   builds. Neither gets under 500 kB while Fluent UI v9 is the UI layer.
3. **Code-split via `manualChunks` or dynamic `import()`.** Not viable — incompatible with
   `inlineDynamicImports` + `iife`, and explicitly disallowed by the PPTB loading constraint above.

**Recommendation:** apply fix 1 from each section — `vite.config.mts` (or `"type": "module"`) for warning
1, and a raised `chunkSizeWarningLimit` with an explanatory comment for warning 2. Both are low-risk,
compatible with the tool's constraints, and address the actual noise without chasing unavailable
code-splitting options.

`tools/pcf2bpf` is currently the only tool with a `vite.config.ts` in this repo, so there's no existing
`chunkSizeWarningLimit` precedent to follow — this would set the convention for tools built the same way.
