---
title: "Part 5 — PCF Control Template: Expert Self-Review (r01)"
part: 5
kind: review-log
iteration: 02
author: maciejnowicki
date: 2026-09-10
status: draft
---

# Part 5 — PCF Template: Expert Self-Review (iteration r01)

Reviewing the first build of `ProjectTemplate/PCFControls/` as a top PCF architect would: does it
compile, does it actually prevent the G1–G11 gotchas, and is it genuinely reusable? Findings are
severity-tagged with the file, then fixed in r02 (convergence in `part5-pcf-03-convergence.md`).

Legend: **[BLOCKER]** breaks build/test · **[HIGH]** correctness/gotcha gap · **[MED]** quality ·
**[LOW]** polish.

## Findings

### F1 — [BLOCKER] pcf-core ESM dist breaks the pcf-scripts webpack build
`pcf-core` first emitted an **ESM** `dist` (`"type":"module"`, extensionless relative imports). The
scaffold's webpack build failed: `Can't resolve './disposeBag'` — webpack's strict-ESM mode requires
fully-specified import extensions.
*File:* `pcf-core/package.json`, `pcf-core/tsconfig.build.json`.
*Fix (r02):* emit **CommonJS** (`module: CommonJS`, drop `"type":"module"`, `exports.require`).
Webpack bundles CJS cleanly (extension resolution works). Verified: field + card both build.

### F2 — [BLOCKER] pcf-scripts build type-checks `__tests__`, so a test-only type slip fails the build
The card build failed on `__tests__/mockPcfContext.test.ts` (TS2345: `MockWebApi` vs
`RetrieveMultipleResponse.nextLink`). ts-loader type-checks every file in the tsconfig program,
including tests.
*File:* `scaffold-*/*/tsconfig.json`.
*Fix (r02):* `exclude` `**/__tests__/**` + `*.test.ts(x)` from the control tsconfig — tests are validated
by vitest, never shipped in the bundle.

### F3 — [BLOCKER] ESLint (in the build) rejects `||` and two-arg `.then`
`@typescript-eslint/prefer-nullish-coalescing` flagged `placeholder.raw || …` (field index); the
`promise/*` rules flagged `acknowledge(...).then(ok, err)` and a bare `void openRecordInDialog(...)`
(card index).
*Files:* `scaffold-field/.../index.ts`, `scaffold-virtual-card/.../index.ts`.
*Fix (r02):* `??` (a text `.raw` is `null` when empty, so `??` is also semantically right); split into
`.then(…).catch(…)` with an explicit `return;` in the `then`.

### F4 — [BLOCKER] React 16 `react/jsx-runtime` unresolved under vitest/jsdom
Fluent's `@griffel/react` imports the extensionless `react/jsx-runtime`, which React 16.14 exposes only
as a file (no package `exports` map), so vitest's native-ESM resolution of externalized node_modules
fails.
*File:* `scaffold-*/vitest.config.ts`.
*Fix (r02):* alias `react/jsx-runtime`(+dev) to the resolved file AND `server.deps.inline` `@fluentui`/
`@griffel` so Vite (which honours the alias) resolves them. Verified: component tests pass.

### F5 — [HIGH] `index.ts` risked repeating the live-delivery source's "one giant file" weakness
The analysis calls out the live-delivery source's ~1,600-line `index.ts`. The card orchestrator must show many patterns
without bloating.
*Fix (already in design):* all reusable machinery is in `pcf-core`; per-control logic is in `services/`;
the card `index.ts` is ~160 lines. Confirmed thin. No further change.

### F6 — [MED] Field bundle (~74 KB) exceeds the analysis's "≤50 KB field" budget
A Menu/dropdown field pulls in Fluent `Menu*`. This is real, not a leak (React/Fluent are externalized;
only control code + pcf-core are bundled).
*Fix (r02):* documented the budget as a guideline (a Menu-based field runs 50–80 KB) in GOTCHAS.md,
rather than pretending 50 KB is always achievable.

### F7 — [MED] Sharing model (`pcf-core`) needed an explicit decision + rationale
Copy-paste (live-delivery source) vs npm package vs local `file:` package. Left implicit, a future contributor could
re-introduce copy-paste drift.
*Fix (r02):* recorded in ADR-0006 §B and README "How the scaffolds consume pcf-core": local `file:`
package shipping compiled `dist`.

### F8 — [LOW] Dataset scaffold could be mistaken for build-verified
The live-delivery source never shipped a dataset control; a half-real one would over-promise.
*Fix (r02):* kept as `*.reference.*` files + a README explicitly labelling it a documented stub with a
"promote to full scaffold" recipe.

### F9 — [HIGH] Harness detection + config-read safety must be regression-proof
AP-930 (a real Dataverse host publishing `pcf_tools_*`) and AP-884 (blocking alerts) are the exact
traps.
*Verified:* `pcf-core/harness.ts` requires loopback origin AND the global; `deferredConfigRead`
short-circuits in the harness via `onSkip` (keeping the real fallback). Tests port the AP-930 regression
(`__tests__/harness.test.ts`). No change.

## Verification run at r01→r02

- `pcf-core`: `tsc --noEmit` clean; `vitest` **61/61 pass** (incl. the G1 DOM repaint proof and the
  AP-930 harness regression).
- `scaffold-field`: `npm run build` **succeeds** (bundle emitted, React/Fluent externalized); `vitest`
  **8/8 pass**.
- `scaffold-virtual-card`: build + tests re-run after F1–F4 fixes (see convergence).
