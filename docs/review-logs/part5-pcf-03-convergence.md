---
title: "Part 5 — PCF Control Template: Convergence"
part: 5
kind: review-log
iteration: 03
author: aidevme
date: 2026-09-10
status: accepted
---

# Part 5 — PCF Template: Convergence

The build→self-review→improve loop (ADR-0001 method) converged after two iterations. All r01
**[BLOCKER]** and **[HIGH]** findings are resolved and verified with REAL build/test runs; residual
items are documented, not silently dropped.

## r01 → r02 resolution

| # | Finding | Sev | Resolution | Verified |
|---|---------|-----|-----------|----------|
| F1 | pcf-core ESM dist broke webpack | BLOCKER | Emit CommonJS `dist` (drop `type:module`, `exports.require`) | field + card `npm run build` succeed |
| F2 | build type-checked `__tests__` | BLOCKER | `exclude` tests from control tsconfig | card build clean |
| F3 | ESLint `||` / two-arg `.then` | BLOCKER | `??`; `.then(…).catch(…)` + explicit return | build passes ESLint gate |
| F4 | React16 `jsx-runtime` under vitest | BLOCKER | alias + inline `@fluentui`/`@griffel` | component tests pass |
| F5 | thin `index.ts` | HIGH | machinery in pcf-core; card index ~160 lines | code review |
| F6 | field bundle > 50 KB | MED | documented as guideline (Menu field 50–80 KB) | GOTCHAS.md |
| F7 | pcf-core sharing model | MED | local `file:` package (ADR-0006 §B) | README + ADR |
| F8 | dataset could over-promise | LOW | kept as `*.reference.*` stub + README | — |
| F9 | harness/config-read safety | HIGH | loopback AND global; AP-930 regression test | pcf-core vitest |
| F10 | Fluent `MessageBar` not stable in the pinned 9.46.2 → the card's error-path renders undefined (2 tests failed) | HIGH | replaced with a token-styled `role="alert"` div (version-portable, a11y) | card **22/22 pass** |

## Final verification (real runs, Node 22 / npm 11)

| Package | `npm run build` (pcf-scripts) | Tests (vitest) |
|---------|-------------------------------|----------------|
| `pcf-core` | n/a (library — `tsc` build to `dist`, clean) | **61/61 pass** (10 files) |
| `scaffold-field/CustomerChoiceField` | **Succeeded** — `out/controls/.../bundle.js` (~74 KB), React/Fluent externalized (`Reactv16` / `FluentUIReactv940`) | **8/8 pass** |
| `scaffold-virtual-card/CustomerInsightCard` | **Succeeded** — bundle (~88 KB), externalized | **22/22 pass** |

The G1 fix is proven in a DOM: `pcf-core/__tests__/storeReact.test.tsx` mounts `<LiveState>` and asserts
it repaints on `store.set(...)` with NO external re-render — exactly the situation where a dropped
`notifyOutputChanged` would leave a real control stale. The AP-930 harness regression is locked by
`pcf-core/__tests__/harness.test.ts`.

## Residual risks (accepted / handed forward)

1. **`pac pcf push` not exercised** — ADR-0001 forbids deploy; the build produces the exact bundle
   `push` would upload, and `tools/Verify-DeployedBundle.ps1` covers the post-deploy content check (G2).
   First real push should confirm the manifest `namespace`/`constructor` → web-resource name mapping the
   verify tool assumes.
2. **Dataset scaffold is a documented stub**, not build-verified — by design (the live-delivery source never shipped one).
   Promote per its README when a project needs a grid.
3. **Test first-run cost** — inlining Fluent for jsdom makes the first `npm test` ~1–2 min. Acceptable;
   documented in onboarding. A lighter alternative (component tests against a shimmed Fluent) was not
   pursued to avoid diverging test rendering from production.
4. **`dataverse-gen` depth** — the template ships curated typed tables + a `.dataverse-gen.json`; whether
   to generate the full early-bound surface per control is left to each project (small Web API surface
   per control makes curation cheap).

## Conclusion

The PCF template compiles, tests green, and encodes every G1–G11 lesson as code/guards/tests. It is
neutral (ADR-0003 tokens), reusable (copy-a-scaffold + rename), and improves on all four of the live-delivery source's
weaknesses (no component tests → covered; giant index → thin; magic strings → typed; copy-paste helpers
→ shared `pcf-core`). **Converged.**
