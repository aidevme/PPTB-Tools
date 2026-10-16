---
adr: 0006
title: PCF control template architecture
status: accepted
date: 2026-09-10
author: maciejnowicki
supersedes: []
---

# ADR-0006 — PCF control template architecture

## Context

The template needs a reusable, best-in-class PowerApps Component Framework (PCF) layer. Of the three
sources (ADR-0001), only **the live-delivery source** ships real PCF controls (13 of them); **HINT** has a stale README
stub that froze old advice (field / React 17 / Fluent 8), and **CDX** has no client-UI story at all
(`docs/review-logs/part5-pcf-01-source-analysis.md`). So the PCF layer is authored fresh from the live-delivery source's
hard-won patterns, generalised and made neutral (ADR-0003), and improved on the live-delivery source's known weaknesses:
no component/lifecycle tests, a ~1,600-line `index.ts`, magic-string Web API calls, and copy-pasted
per-control helpers.

Constraints: virtual controls must run on the platform's React 16.14 / Fluent 9.46.2; the sandbox build
must be production mode (Solution Checker `web-avoid-eval`); local-only, no deploy (ADR-0001 §8).

The build ran the ADR-0001 loop: build → self-review (`part5-pcf-02-review-r01.md`) → fix → converge
(`part5-pcf-03-convergence.md`).

## Options considered

### A. Repaint of internal (non-bound) async state
1. **`notifyOutputChanged` (+ a "repaint nudge")** — the naive path. Pros: platform-native. Cons: the
   platform DROPS it when `getOutputs()` returns `{}` (which is correct for a webAPI-persisting
   control), so the UI never repaints — proven live in a live-delivery engagement. A nudge re-issues the same
   dropped call. **Rejected.**
2. **Self-render into the container** — bypass the ReactControl contract. Cons: fights the platform
   lifecycle, breaks virtual-control assumptions. **Rejected.**
3. **External store + React subscription** (`pcf-core/store.ts` + `LiveState`). Pros: repaints
   independently of `updateView`; tiny; testable; React-16-compatible (manual subscription, no
   `useSyncExternalStore`). **Chosen.**

### B. Sharing the common helpers across controls
1. **Copy-paste per control** (what the live-delivery source does). Cons: fixes don't propagate; drift. **Rejected.**
2. **Published npm package** (private registry). Cons: the live-delivery source's registry is flaky (CLAUDE.md); adds a
   publish/version step to every fix. **Rejected for the template.**
3. **`pcf-core` as a local `file:` package shipping compiled `dist/` (CommonJS + `.d.ts`)**. Pros: one
   source of truth; fixes propagate by rebuilding; no registry; `pcf-scripts` (webpack) bundles the
   compiled JS cleanly because it excludes `node_modules` from TS compilation — which is exactly why
   pcf-core must ship JS, not TS (an ESM `dist` also failed webpack's fully-specified-import check, so
   CommonJS is the deploy-valid emit). **Chosen.**

### C. Test runner
1. **jest** — heavier config for ESM/Fluent 9. 2. **vitest + @testing-library/react + jsdom** — the live-delivery source
   already uses vitest for services; adding jsdom + RTL extends it to components/lifecycle with minimal
   new surface. **Chosen** (vitest). The one cost — React 16 has no `exports` map for its
   `react/jsx-runtime` subpath that Fluent's `@griffel/react` imports — is handled by a vitest alias +
   inlining `@fluentui`/`@griffel` so Vite resolves them (documented in the scaffold `vitest.config.ts`
   and onboarding).

### D. Killing magic-string Web API calls
1. **Magic strings** (the live-delivery source). Cons: typos surface at runtime. 2. **`TypedWebApi` generic over an
   early-bound entity type** (`dataverse-gen` or a curated interface). Pros: compile-time table/column
   checking; a thin pass-through over `context.webAPI` (never `fetch`/`Xrm.WebApi`); aligns with the
   Client layer's `dataverse-gen`. **Chosen.**

## Decision

A **config-driven, neutral-token** PCF template with a shared **`pcf-core`** library and **two
build-verified scaffolds** (field + virtual card) plus a documented **dataset** reference stub:

- **`pcf-core`** (compiled `file:` package, unit-tested): `createStore`/`LiveState` (G1),
  `crossPlacementSync` (G6), `isLocalTestHarness` (G7), `getHostId` + `PreviewCard` (G5), `xrmBridge`
  (G11), `createDeferredRead`, `TypedWebApi`, `FluentRoot`/theme resolution, `DisposeBag`.
- **scaffold-field** (`CustomerChoiceField`): bound control, writes back via `getOutputs()`.
- **scaffold-virtual-card** (`CustomerInsightCard`): webAPI-persisted state (getOutputs `{}`) →
  external-store repaint; deferred config read; sibling sync; Xrm dialog escape hatch.
- **scaffold-dataset**: documented reference (the live-delivery source never shipped a dataset control).
- **formscripts/tabStateSync.js** (G3/G4), **tools/Verify-DeployedBundle.ps1** (G2),
  **test-harness/mockPcfContext.ts**, **GOTCHAS.md**, **solution/** publisher discipline.
- Pinned stack: virtual / React 16.14 / Fluent 9.46.2 via `<platform-library>`; TypeScript strict;
  `PcfBuildMode=production`; flat ESLint + `@microsoft/eslint-plugin-power-apps`; resx cache-by-version.

## Rationale

- **Reusability**: neutral `Customer` / `hso_customer_` tokens (ADR-0003); one rename yields a coherent
  control. Helpers live once in `pcf-core`, so a gotcha fix propagates to every control.
- **Bulletproof = proven**: both scaffolds `npm ci && npm run build` (pcf-scripts production build,
  React/Fluent externalized) AND `pcf-core` + both scaffolds pass vitest — the "buildable and tested"
  ADR-0001 §6 bar. The G1–G11 lessons are encoded as CODE/guards/tests, not prose.
- **Better than the sources**: component/lifecycle tests (the live-delivery source had none), a thin `index.ts` (helpers
  extracted), typed Web API (no magic strings), a real dataset reference (CDX/HINT had nothing).

## Consequences

- New controls copy a scaffold and rename tokens; `pcf-core` is a `file:` dependency they never edit.
- A pcf-core change requires rebuilding its `dist/` (its `prepare` script does this on `npm ci`); the
  compiled boundary keeps the webpack build clean.
- The template owns the current version pins — it is the single source of truth that HINT's stub failed
  to be, and must be updated here (not per control) when the platform moves.
- Follow-on (open): promote the dataset stub to a full scaffold when a project needs a grid; decide
  whether to run `dataverse-gen` per control or keep curated typed tables for small surfaces.
