---
title: "Part 5 — PCF Control Template: Source Analysis"
part: 5
kind: review-log
iteration: 01
author: aidevme
date: 2026-09-10
status: draft
scope: read-only comparative analysis of PCF tooling across the live-delivery source / HINT / CDX
sources_are_read_only: true
inputs:
  - live-delivery source: C:\Repos\workspace\NewHorizon-App-SalesAI-CRM\PCFControls
  - HINT:  C:\Repos\HINT-Pipelines\ProjectTemplate\PCFControls
  - CDX:   C:\Repos\HSO-Power Platform Pipeline Template - CDX
---

# Part 5 — PCF Control Template: Source Analysis (iteration 01)

Read-only comparative study of how the three template sources handle PowerApps Component
Framework (PCF) controls, feeding the build of a **reusable, best-in-class PCF control template**
(a virtual/React scaffold **and** a field scaffold). Only **the live-delivery source** ships real, battle-tested PCF
controls; **HINT** has a README placeholder; **CDX** has none.

---

## 0. Source inventory (what actually exists)

| Source | PCF present? | What's there |
|--------|--------------|--------------|
| **live-delivery source** | **Yes — 13 real controls** | `PCFControls/` holds `AccountContextCard`, `CaseActionBar`, `ChoiceIcon`, `ContactQuickActions`, `ConversationMap`, `ConversationTaxonomyManager`, `FollowUpReminderCard`, `LatestEmailCard`, **`ProductRecommendations`** (the flagship, v0.24.4), `QuoteCard`, `QuotePdfCard`, `StatusTimeline`, plus a top-level README. A mature, project-specific skill (`.claude/skills/hso-pcf-control-development`) + a 7-file SOP family govern them. |
| **HINT** | **Placeholder only** | `ProjectTemplate/PCFControls/` = a `.gitignore` + a 774-byte `README.md`. The README prescribes the intended workflow: `pac pcf init --namespace HSO.PCF --template field --framework react`, `npm install`, add `@fluentui/react@8.121.1`, build with `npm run build` / `npm start watch`, deploy with `pac pcf push --publisher-prefix hso`, and "follow the PCF SOP in `.shared/SOP/PCFControls/`, use React 17.0.2 + Fluent 8.x for StandardControl". **It is a byte-near-identical copy of the live-delivery source's own top-level `PCFControls/README.md`** — i.e. HINT captured the live-delivery source's *intent* as a template stub but never built a control. Note the drift: the README still says **field template / React 17.0.2 / Fluent 8**, whereas the live-delivery source's live controls have all moved to **virtual / React 16.14.0 / Fluent 9**. |
| **CDX** | **None — confirmed** | The tree under `C:\Repos\HSO-Power Platform Pipeline Template - CDX` contains **no `*.pcfproj` and no `ControlManifest*.xml`**. CDX is a server/client/pipeline template (DataverseModel/Plugins/Services/Tests, a `dataverse-gen` TS client + rule engine, structured error framework). **The client-side UI story is entirely absent — this is the single biggest gap the new template must close, and the live-delivery source is the only place to harvest it from.** |

**Consequence for the template:** the reusable PCF layer must be **authored fresh from the live-delivery source's
hard-won patterns**, not copied from HINT (a stale stub) and not derivable from CDX (nothing there).
Everything below is harvested from the live-delivery source.

---

## 1. How the live-delivery source builds PCF

### 1.1 Control type — virtual/React is the standard; StandardControl is legacy

Every current control in the live-delivery source is `control-type="virtual"` implementing
`ComponentFramework.ReactControl<IInputs, IOutputs>`. The SOP is explicit: **Virtual-only**,
React `16.14.0` + Fluent UI `@fluentui/react-components` `9.46.2`, declared via `<platform-library>`
so the **platform supplies React/Fluent at runtime** (the control never bundles them).

| Framework | React | Fluent UI | Manifest |
|-----------|-------|-----------|----------|
| **ReactControl (virtual, preferred)** | 16.14.0 (manifest) / 17.0.2 (runtime) | `@fluentui/react-components` 9.46.2 | **KEEP** `<platform-library>` |
| StandardControl (legacy, avoid) | 17.0.2 | `@fluentui/react` 8.121.1 | **REMOVE** `<platform-library>`; must bundle Fluent (multi-MB tax) |

The manifest declares a *minimum/compatible* version; the runtime provides the actual library
(React 16.14.0 → 17.0.2 at runtime; Fluent stays 9.46.2). The lesson: never hand-bundle React or
`@fluentui/react-icons` in a virtual control.

### 1.2 Manifest structure (`ControlManifest.Input.xml`)

Studied against `ProductRecommendations` (a rich orchestrator card) and `ChoiceIcon` (a lean,
reusable field control). The manifest is the control's public contract:

- `<control namespace="HSO" constructor="…" version="x.y.z" control-type="virtual">` — the
  **version here is the deploy slot** (see the clobber lesson §2).
- `<external-service-usage enabled="false" />`.
- **`<property>` per input/bound value.** Types seen in the wild: `Multiple` (memo JSON),
  `SingleLine.Text`, `TwoOptions`, `OptionSet`, `Enum` (with `<value>` children + `default-value`),
  `Whole.None`. `usage="bound"` (read/write against a form column) vs `usage="input"` (config).
  `required` per property.
- **`<feature-usage>`** — MANDATORY when the control calls platform APIs, or it fails at runtime
  (`Feature 'X' is required…`): `WebAPI` for `context.webAPI.*`, `Utility` for `context.navigation.*`
  / `context.utils.*`, `Device.*` for device APIs. `ProductRecommendations` declares both
  `WebAPI` and `Utility`; `ChoiceIcon` declares none (it only reads its bound value + option metadata).
- **`<resources>`** — `<code path="index.ts">`, the two `<platform-library>` lines, `<css>`, and a
  **`<resx path="strings/*.1033.resx" version="…">`** whose `version` **must be bumped on every resx
  change** — the runtime caches strings (and the stylesheet) by that version, so new keys shipped
  without a bump render as **raw key names**.

**Design pattern worth codifying:** the live-delivery source keeps *bound* properties minimal and pushes most config
into `usage="input"` properties **and Dataverse environment variables / config tables read via
`context.webAPI` on init** (e.g. `hso_ProductMatchDebug`, `hso_ProductExpertReachOutConfig`,
`hso_stockplancategory`). These are **deliberately NOT manifest properties** — they're runtime reads,
which keeps the form binding stable while allowing per-environment behaviour.

### 1.3 Project layout

```
ProductRecommendations/                         (control root)
├── ProductRecommendations.pcfproj              MSBuild project (net462, PcfBuildMode=production)
├── package.json                                pcf-scripts + deps + test scripts
├── tsconfig.json                               extends node_modules/pcf-scripts/tsconfig_base.json
├── pcfconfig.json                              { "outDir": "./out/controls" }
├── eslint.config.mjs                           flat config, typed-lint + power-apps + react + promise
├── .gitignore                                  node_modules, generated/, out/, bin/, obj/, *.binlog, .vs
└── ProductRecommendations/                     (the control's source folder = constructor name)
    ├── ControlManifest.Input.xml
    ├── index.ts                                the ComponentFramework.ReactControl class
    ├── generated/ManifestTypes.ts              (gitignored) typed IInputs/IOutputs from the manifest
    ├── components/                              *.tsx React components (MatcherWorkspace, ProductSelection, …)
    ├── services/                               *.ts pure logic + *.test.ts (vitest) — 22 test files
    └── styles/  strings/                        CSS + .1033.resx
```

The **`index.ts` (lifecycle) / `components/` (React) / `services/` (pure logic + tests)** split is
the single most important structural idea to carry into the template. `services/` files are kept
**free of PCF/React imports** so they are trivially unit-testable — this is why 22 vitest suites
exist without a DOM.

### 1.4 State / repaint model (the crux)

A virtual control's only sanctioned self-repaint is `notifyOutputChanged()` → *maybe* `updateView`.
The live-delivery source learned the hard way that this is **unreliable**, and evolved three repaint strategies, chosen
by *what changed*:

1. **A bound-output change** — normal path. If the control's value rides a bound output, changing it
   forces `updateView`. `ChoiceIcon` uses this cleanly: pick an option → written back via
   `getOutputs()`.
2. **A bound-value push (cross-tab sync)** — a *form script* refreshes a bound column from the server
   (`addTabStateChange` → `setSubmitMode("never")` + `setValue`); the change reliably forces
   `updateView` with the new value already in `context.parameters`, adopted **synchronously**.
3. **A per-instance React store subscription** — for **internal async state that has no bound-output
   channel** (`ProductRecommendations.getOutputs()` returns `{}` because it persists via Web API).
   Here `notifyOutputChanged` is *dropped by the platform*, so the control publishes state into a
   tiny `createReadinessStore()` and a mounted `LiveReadiness` wrapper subscribes (manual
   `useState`+`useEffect` — React 16, no `useSyncExternalStore`), repainting **independently of
   `updateView`**.

### 1.5 Bound-column read/write

- **Read:** `context.parameters.<prop>.raw`, parsed **defensively** (envelope-tolerant JSON parsers
  in `services/groupParser.ts`; a parse failure renders an explicit error state, never throws).
- **Write, two idioms:**
  - **`getOutputs()`** returns the new bound value (the classic, platform-native path —
    `ChoiceIcon`).
  - **`context.webAPI.updateRecord`** writes straight to Dataverse columns the control owns but does
    *not* bind for output (`ProductRecommendations` persists the selection overlay, confirmation memo,
    and status flip this way — ADR 0013 — so an orchestrator re-send can't clobber the rep's picks).
    The trade-off is that a Web API write **never updates the form's in-memory attribute**, so the
    bound `.raw` stays at its form-load value — the root cause of both the cross-tab-sync and the
    dropped-notify problems.

### 1.6 Dataset vs field controls

The live-delivery source's live controls are **all field/bound controls** (bound to columns on a form). No dataset
(grid/view) control ships today, though the SOP documents dataset patterns (customizer
`cellRendererOverrides`/`cellEditorOverrides`, `dataset.refresh()`, paging contract). The template
should still scaffold a **dataset variant stub**, because the SOP calls it out and CDX/HINT give
nothing — but the primary, proven scaffold is the **field/bound virtual control**.

### 1.7 Build / deploy / test / versioning

- **Build:** `npm run build` = `pcf-scripts build`; `.pcfproj` pins `net462` and
  **`<PcfBuildMode>production</PcfBuildMode>`** (see §2 — without it, `pac pcf push` forces a *dev*
  eval build that trips Solution Checker `web-avoid-eval`).
- **Deploy:** `pac pcf push --publisher-prefix hso`. **Publisher prefix `hso` is fixed for the life
  of the control** — a PCF cannot be redeployed through a pipeline under a different publisher, which
  is why the live-delivery source keeps PCF in a dedicated wave (`SourceAIWavePCF01`, publisher `HSO`) separate from the
  general `SourceAIWave01` (publisher `Source`).
- **Test:** **vitest** (`vitest run` / `vitest`), **not jest**. 22 `*.test.ts` suites, all in
  `services/` (pure logic). **No component (`.tsx`) tests, no jsdom, no test-harness rendering of
  React** — a real gap (see §3). ESLint excludes tests from the typed-lint pass (they run under
  esbuild, outside the build tsconfig).
- **Versioning discipline:** monotonic PATCH bumps in the manifest per change; resx `version`
  bumped independently on any string/style change. **A higher version is NOT proof a fix is
  deployed** (§2).
- **Solution membership:** the control lives in **two** solutions — its ticket solution (authoring)
  and the PCF wave aggregator (`SourceAIWavePCF01`) for release. An orphan check
  (`Get-OrphanedComponents.ps1`) guards against a control that lives only in a ticket solution and
  therefore never deploys.

---

## 2. Hard-won lessons / gotchas → "the template must prevent/handle this"

Each lesson from the live-delivery source is turned into a template requirement.

| # | Gotcha (live-delivery source) | Evidence | Template MUST… |
|---|----------------|----------|----------------|
| G1 | **`getOutputs()` returning `{}` makes the platform DROP `notifyOutputChanged`** — internal async state never repaints (AP-1326: Send gate re-read the DB correctly but the button never re-rendered). `scheduleRepaintNudge` just re-issues the same dropped notify. | `index.ts` `createReadinessStore`/`LiveReadiness`; memory `productrec-getoutputs-repaint-drop`. | Ship a **per-instance external store + subscription helper** (`createStore`/`useStoreSubscription`) as the sanctioned repaint path for non-bound internal state. Document: if a control persists via Web API (getOutputs `{}`), you MUST NOT rely on `notifyOutputChanged` to repaint. |
| G2 | **PCF version-slot clobber** — `pac pcf push` replaces the *whole* bundle and the version slot is a TOCTOU race; a later push from a branch predating a fix silently reverts it *while the version number goes up* (AP-1171: deployed 0.19.12 still ran old code). | memory `pcf-version-slot-clobber`. | Bake a **deploy checklist + verify step**: read the live version immediately before every push, bump monotonically, and **verify the deployed `bundle.js` content** (base64-decode the webresource, grep for the fix needle) — never trust the version number. |
| G3 | **A PCF-bound column is only a form ATTRIBUTE if it's the control's PRIMARY `datafieldname`.** A secondary bound `<parameters>` property returns **null** from `formContext.getAttribute()`, so a form script can't `setValue`/`onChange` it (AP-1120: this one missing hidden field silently broke the whole sync fix). | memory `ap-1120-crosstab-sync`; SKILL "Bound fields, form scripts & cross-placement sync". | Document the rule prominently; the cross-tab-sync recipe MUST include "add the secondary column to the form as a **hidden field**" as step 0. |
| G4 | **`notifyOutputChanged` is dropped for a just-shown (previously hidden) tab** — poll, in-page event, and IntersectionObserver "became visible" triggers are ALL unreliable for repaint. | SKILL §"virtual PCF cannot reliably repaint itself"; AP-1114 repaint-nudge machinery. | Provide the **reliable cross-tab-sync pattern** (bound-value change via `addTabStateChange` form script) as a first-class template recipe + a companion form-script snippet. Mark poll/event/observer approaches as anti-patterns. |
| G5 | **Design-time / unsaved-record host** — the maker designer and a new unsaved record have no `entityId`; a control that goes straight to data access shows **"Error loading control"**. And `init()` config reads fired before an id exists are skipped for the instance's life. | SKILL "Design-Time Preview"; `getHostId`/`PreviewCard`. | Scaffold a **`PreviewCard` inert shell** + the `if (!host?.id) return <PreviewCard/>` guard, AND a **`maybeStartConfigReads` deferred-read pattern** (re-checkable from `updateView`, once-guarded) so reads start when the id first appears. |
| G6 | **A Web API write never refreshes the bound `.raw`** — so a second placement (or a re-open) shows the form-load value, not the persisted one. | `overlaySync.ts`, `stockPlanConfigSync.ts`. | Provide a **module-scoped in-page pub/sub** helper (publish/subscribe/get + late-mount catch-up + sender-id echo suppression) for syncing sibling placements and sharing config reads. |
| G7 | **The local `pcf-start` harness's mock WebApi pops a blocking `alert()` on `retrieveMultipleRecords` BEFORE rejecting** — no try/catch can suppress it; and a fake hard-coded `entityId` defeats the host-id guard. Detecting "am I the harness" by a global alone is unsafe (`pcf_tools_*` exists on real hosts too — AP-930 skipped every read org-wide). | `services/harness.ts`. | Ship an `isLocalTestHarness()` helper gated on **loopback origin AND** the runtime global (both required), and have config-read starters short-circuit in the harness with each loader's real fallback. |
| G8 | **`pac pcf init` scaffolds an invalid Fluent `9.68.0`** (platform can't resolve `fluent_9_68_0`) and **`pac pcf push` forces `PcfBuildMode=development`** (eval build → Solution Checker critical). | SKILL "Verifying Platform Library Versions". | Template's `ControlManifest.Input.xml` ships **Fluent 9.46.2** already, and the `.pcfproj` ships **`<PcfBuildMode>production</PcfBuildMode>`** already — no post-init fix-up needed. |
| G9 | **resx cache-by-version** — new strings/styles shipped without bumping the `<resx version>` render as raw key names / stale CSS. | manifest comments in `ProductRecommendations`. | Template README + pre-deploy checklist: bump `<resx version>` on ANY string or CSS change. |
| G10 | **`<feature-usage>` omission = runtime failure.** | SKILL "Feature Declarations". | Scaffold generates the `<feature-usage>` block from the APIs the template actually calls; checklist item ties each `context.*` call to its feature. |
| G11 | **No `Xrm.*` in a PCF** — but a few genuinely need the global (`Xrm.Navigation.navigateTo` for a centered dialog, `Xrm.Page.ui.tabs` for tab focus, a live dirty form-field value). The live-delivery source isolates these behind **minimal typed interfaces + `getXrm…()` probes that fail safe** (no-op off a model-driven form / in the harness). | `index.ts` `IXrmNavigation`/`IXrmFormTab`/`IXrmAttribute`. | Provide a small **`xrmBridge`** helper module (typed, feature-detected, harness-safe) so the escape hatch is contained and documented, not sprinkled. Default guidance: `context.navigation.*`, never `window.open`. |

---

## 3. Strengths & weaknesses of the live-delivery source's approach

**Strengths (keep):**
- Clean **index.ts / components / services** separation; services are React-free and heavily
  unit-tested (22 suites).
- **Virtual + platform-library** discipline → tiny bundles, no React/Fluent tax.
- **Defensive, envelope-tolerant parsing** with explicit empty/error/loading states.
- **Deferred, once-guarded, harness-aware config reads** with retry/backoff ceilings and
  observability (one `console.debug` line per lifecycle milestone).
- **Fail-safe Xrm escape hatches** behind typed probes.
- **Real deploy discipline** learned in production (version clobber, orphan guard, PCF-wave/publisher
  rules, resx cache).
- A **mature governing skill + 7-file SOP family** encoding all of the above.

**Weaknesses (improve in the template):**
- **No component tests, no DOM harness.** vitest covers only `services/`; the React tree
  (`components/*.tsx`) and lifecycle are untested. → add `@testing-library/react` + jsdom.
- **No storybook-like local harness.** The only local runner is `pcf-start`, whose mock WebApi is so
  hostile (blocking alerts) that a whole `harness.ts` exists just to *disable* behaviour in it. There
  is no fast, WebApi-mocked visual harness.
- **`index.ts` has grown huge** (~1,600 lines on `ProductRecommendations`) — lifecycle, ~10 config
  reads, retry loops, three sync buses, and Xrm bridges all in one file. The template should factor
  these into reusable helper modules so a new control's `index.ts` stays thin.
- **Manifest typing is one-directional** — `generated/ManifestTypes.ts` types `IInputs/IOutputs`, but
  there's no early-bound typing of the **Dataverse columns/tables** the Web API reads/writes (magic
  strings like `"incident"`, `"hso_productselection_memo"` throughout). CDX already solves this with
  `dataverse-gen`; the PCF template should adopt it.
- **No shared "PCF core" library.** Every control re-implements the store/sync/harness/preview/xrm
  patterns by copy-paste. The template should extract a versioned `pcf-core` (or a documented shared
  folder) so fixes propagate.
- **Bundling/version verification is manual.** The clobber lesson should be a scripted post-deploy
  bundle-content assertion, not tribal knowledge.
- **HINT drift** shows the risk of a stub template: it froze the *old* field/React-17/Fluent-8 advice.
  The new template must be the single source of truth and keep versions current.

---

## 4. Best-in-class recommendation — the reusable PCF template

A **config-driven, neutral-named** template (`HSO.Customer.*` token) offering **two scaffolds** plus a
shared core. Nothing project-specific baked in.

### 4.1 Chosen stack

| Concern | Choice | Why |
|---------|--------|-----|
| Control type | **Virtual (`ReactControl`)** primary; field + dataset variants | Proven; smallest bundle; platform-supplied libs. |
| React | **16.14.0** (manifest) / 17.0.2 runtime, via `<platform-library>` | Matches the live-delivery source's runtime; no bundling. |
| Fluent UI | **`@fluentui/react-components` 9.46.2** (`<platform-library>`) | The one deploy-valid value (NOT 9.68.0). |
| Language | **TypeScript 5.x, strict** | SOP mandate; discriminated-union state. |
| Manifest types | **`pcf-scripts refreshTypes` → `generated/ManifestTypes.ts`** | Typed `IInputs/IOutputs`. |
| Dataverse types | **`dataverse-gen` early-bound types** (harvested from CDX) | Kills magic-string columns/tables in Web API calls. |
| Unit tests | **vitest** + **`@testing-library/react`** + **jsdom** | Keep the live-delivery source's vitest; ADD component/lifecycle tests (the gap). |
| Local harness | **`pcf-start`** for parity **+** a **jsdom/vitest render harness with a mocked `context` (incl. `webAPI`)** | Fast, alert-free visual/logic harness the real thing lacks. |
| Lint | **flat ESLint**: `typescript-eslint` typed + `@microsoft/eslint-plugin-power-apps` (paCheckerHosted) + react + promise | Mirrors the live-delivery source; power-apps plugin pre-empts Solution Checker. |
| Build | `pcf-scripts build`, **`PcfBuildMode=production`** in `.pcfproj` | Avoids `web-avoid-eval`. |
| Styling | **`FluentProvider` + `IdPrefixProvider` wrap**, tokens only (no hardcoded colours) | SOP mandate; unique aria ids across placements. |
| i18n | **`.resx` (LCID) + `context.resources.getString`**, versioned | No hardcoded strings; bump on change. |
| Repaint | **external-store subscription helper** for non-bound state; bound-output/`getOutputs` where a bound channel exists | Survives dropped `notifyOutputChanged`. |
| Navigation | **`context.navigation.*`** only; `xrmBridge` escape hatch feature-detected | Never `window.open`. |

### 4.2 Shared `pcf-core` helpers (extracted from the live-delivery source, generalised)

- `createStore()` + `useStoreSubscription()` — the G1 repaint-safe external store.
- `crossPlacementSync()` — module-scoped publish/subscribe/get with late-mount catch-up + echo
  suppression (G6), plus the companion **`tabStateSync` form-script snippet** for G3/G4.
- `isLocalTestHarness()` — loopback-origin + runtime-global gated (G7).
- `PreviewCard` + `useHostId()`/`getHostId()` — design-time guard (G5).
- `xrmBridge` — typed, feature-detected, harness-safe `Xrm.*` escape hatch (G11).
- `deferredConfigRead()` — once-guarded, retry-with-ceiling, harness-aware env-var/config-table reader.
- `mockPcfContext()` (test util) — a typed fake `context` with a stub `webAPI` for jsdom tests.

### 4.3 Lifecycle-correct skeleton (both scaffolds)

```
init(context, notifyOutputChanged, state):
  - synchronous only; trackContainerResize if the layout is responsive
  - wire services (new Xxx(context.webAPI)); subscribe sync buses; bind xrmBridge listeners
  - maybeStartConfigReads(context)  // no-op if getHostId(context)===null OR isLocalTestHarness()
updateView(context) -> ReactElement:
  - this.context = context
  - maybeStartConfigReads(context)  // late-start once an id appears
  - if (!getHostId(context)) return <PreviewCard/>
  - parse context.parameters.*.raw defensively; adopt any pushed bound-value / sibling state
  - return <FluentProvider><IdPrefixProvider><LiveReadiness store=… render=…/></…></…>
getOutputs(): return the bound outputs — OR {} and persist via webAPI (then use the store for repaint)
destroy(): disposed=true; clear EVERY timer; unsubscribe EVERY bus; remove EVERY window/xrm listener
```

---

## 5. Things the user may have missed (a PCF template needs these, and no other source has them)

Because CDX/HINT contribute **nothing** here, the brief could easily under-scope the PCF layer. Call
these out explicitly:

1. **Manifest property taxonomy & typed generation** — the full `of-type` set (`Multiple`,
   `TwoOptions`, `OptionSet`, `Enum` with `<value>`+`default-value`, `Whole.None`, `SingleLine.Text`),
   bound-vs-input semantics, and `pcf-scripts refreshTypes`.
2. **`<feature-usage>` declarations** — omission = runtime crash (G10).
3. **`<platform-library>` React/Fluent** — the exact deploy-valid versions, and the `pac pcf init`
   9.68.0 trap + `PcfBuildMode=production` trap pre-fixed in the scaffold (G8).
4. **resx / localisation + cache-by-version** (G9).
5. **Design-time preview shell** — or the maker designer shows "Error loading control" (G5).
6. **The repaint model in full** — `getOutputs()==={}` dropping `notifyOutputChanged`; the
   external-store fix; the bound-value cross-tab-sync recipe incl. the hidden-field requirement
   (G1/G3/G4).
7. **The `pcf-start` harness hostility** + `isLocalTestHarness()` + a real mocked-context test
   harness (G7).
8. **ESLint with `@microsoft/eslint-plugin-power-apps`** (paCheckerHosted) to pre-empt Solution
   Checker locally, plus the Solution Checker rule catalog (`web-avoid-eval`, `web-avoid-modals`,
   `web-use-relative-uri`, `web-avoid-with`…).
9. **Versioning + deploy discipline** — monotonic bumps, **bundle-content verification** (version ≠
   proof), PCF-wave/publisher separation, orphan-component guard (G2, solution membership).
10. **`FluentProvider`+`IdPrefixProvider` mandatory wrap**, tokens-only theming, WCAG 2.1 AA, the
    Drawer/Dialog portal token-resolution nested-FluentProvider fix.
11. **`context.webAPI` not `fetch`/`Xrm.WebApi`; `context.navigation.*` not `window.open`;
    no `localStorage` for sensitive data, no `eval`/`innerHTML`.**
12. **`dataverse-gen` early-bound types on the PCF Web API calls** (borrow from CDX) — the template's
    chance to be *better* than the live-delivery source, which uses magic strings.
13. **Bundle budgets** (50 KB field / 200 KB dataset), the `@fluentui/react-icons` ban + custom-icon
    pattern, path-based imports, `React.memo`/`useMemo`/`useCallback`.
14. **Off-the-shelf survey first** (pcf.gallery, MS KPI Dashboard Suite, FastTrack samples) before
    scaffolding custom — the SOP's mandatory pre-step.

---

## 6. Recommended PCF template structure

```
pcf/
├── README.md                         # versions, workflow, deploy discipline, gotcha checklist
├── pcf-core/                         # shared, versioned, unit-tested helpers (NEW vs the live-delivery source)
│   ├── store.ts                      # createStore + useStoreSubscription (G1 repaint)
│   ├── crossPlacementSync.ts         # in-page pub/sub + late-mount catch-up + echo suppression (G6)
│   ├── harness.ts                    # isLocalTestHarness() — loopback+global (G7)
│   ├── hostId.ts                     # getHostId/useHostId (G5)
│   ├── PreviewCard.tsx               # inert design-time shell (G5)
│   ├── xrmBridge.ts                  # typed, feature-detected Xrm.* escape hatch (G11)
│   ├── deferredConfigRead.ts         # once-guarded, retry-ceiling, harness-aware env-var reads
│   ├── theming.tsx                   # FluentProvider+IdPrefixProvider wrapper
│   └── __tests__/                    # vitest suites for every helper
├── scaffold-field/                   # a bound field control (ChoiceIcon-style, getOutputs write)
│   └── Customer<Name>Field/…         # manifest/index.ts/components/services/styles/strings
├── scaffold-virtual-card/            # a virtual card (ProductRecommendations-style, webAPI write)
│   └── Customer<Name>Card/…
├── scaffold-dataset/                 # a dataset/grid stub (SOP-documented, not yet proven in the live-delivery source)
│   └── Customer<Name>Grid/…
├── test-harness/
│   ├── mockPcfContext.ts             # typed fake context incl. webAPI (jsdom)
│   └── setup.ts                      # jsdom + @testing-library/react setup
├── formscripts/
│   └── tabStateSync.js               # addTabStateChange → setSubmitMode("never")+setValue (G3/G4)
├── tools/
│   └── Verify-DeployedBundle.ps1     # base64-decode webresourceset bundle.js + grep needle (G2)
└── docs/
    ├── ONBOARDING.md                 # rename token, npm ci, refreshTypes, build, push, verify
    └── GOTCHAS.md                    # the checklist below
```

Each scaffold folder mirrors the live-delivery source's proven layout:
`<Constructor>.pcfproj · package.json · tsconfig.json · pcfconfig.json · eslint.config.mjs · <Constructor>/{ControlManifest.Input.xml, index.ts, components/, services/, styles/, strings/, generated/}`
— with `Fluent 9.46.2` and `PcfBuildMode=production` pre-set.

---

## 7. Decision table (concern → chosen approach → why)

| Concern | Chosen approach | Why |
|---------|-----------------|-----|
| Control type | Virtual `ReactControl` (field + card scaffolds; dataset stub) | Proven in the live-delivery source; smallest bundle; platform libs. |
| React/Fluent | Platform-library React 16.14.0 + Fluent 9.46.2 | Only deploy-valid combo; no bundling tax. |
| Manifest types | `pcf-scripts refreshTypes` (`generated/ManifestTypes.ts`) | Typed IInputs/IOutputs. |
| Dataverse types | `dataverse-gen` early-bound (from CDX) | Removes magic-string tables/columns — better than the live-delivery source. |
| Bound write | `getOutputs()` when a bound channel fits; else `context.webAPI` + store repaint | Matches the two real idioms from the live-delivery source; store fixes the dropped-notify case. |
| Repaint of internal state | External store + subscription (`pcf-core/store.ts`) | `getOutputs()==={}` drops `notifyOutputChanged` (G1). |
| Cross-placement/tab sync | `crossPlacementSync` bus + `tabStateSync` form script + hidden bound field | The only reliable repaint is a bound-value change (G3/G4/G6). |
| Design-time host | `PreviewCard` + `getHostId` guard + deferred reads | Avoids "Error loading control"; late-starts reads (G5). |
| Local testing | vitest + `@testing-library/react` + jsdom + `mockPcfContext` | Adds the component/lifecycle coverage the live-delivery source lacks. |
| `pcf-start` hostility | `isLocalTestHarness()` short-circuit | Avoids blocking alerts; keeps real fallbacks (G7). |
| Lint | flat ESLint + `@microsoft/eslint-plugin-power-apps` | Pre-empts Solution Checker locally. |
| Build mode | `PcfBuildMode=production` in `.pcfproj` | Avoids `web-avoid-eval` critical (G8). |
| Fluent init version | Ship 9.46.2 in the manifest | 9.68.0 is unresolvable (G8). |
| Theming | `FluentProvider`+`IdPrefixProvider`, tokens only | SOP mandate; unique aria ids. |
| i18n | `.resx` + `getString`, versioned | No hardcoded strings; cache-by-version (G9). |
| Navigation | `context.navigation.*`; `xrmBridge` for the few real Xrm needs | Never `window.open` (G11). |
| Versioning | Monotonic manifest bump + **bundle-content verify** | A higher version ≠ the fix is live (G2). |
| Solution placement | Ticket solution + **dedicated PCF wave**, publisher fixed | PCF can't repipe under a new publisher; orphan guard. |
| Off-the-shelf | Survey pcf.gallery / MS KPI Suite / FastTrack first | SOP mandatory pre-step; don't rebuild existing. |

---

## 8. Checklist — gotchas the template MUST prevent

- [ ] **Repaint:** if `getOutputs()` returns `{}`, internal state repaints via the store subscription — never a bare `notifyOutputChanged` (G1).
- [ ] **Deploy verify:** after every `pac pcf push`, confirm the deployed `bundle.js` contains the fix (decode + grep), not just a higher version (G2).
- [ ] **Hidden field:** any secondary bound column a form script must touch is added to the form as a hidden field (`getAttribute` is null otherwise) (G3).
- [ ] **Cross-tab sync:** use the bound-value/`addTabStateChange` recipe — never poll/event/observer for repaint (G4).
- [ ] **Preview shell:** `if (!host?.id) return <PreviewCard/>`; every data read guards on the id; `init()` reads are deferred/re-checkable (G5).
- [ ] **Sibling/config sync:** Web-API-written state and per-env config reads share via the in-page bus with late-mount catch-up (G6).
- [ ] **Harness:** `isLocalTestHarness()` (loopback + global) short-circuits config reads; no blocking alerts in `pcf-start` (G7).
- [ ] **Versions:** manifest ships Fluent **9.46.2** and `.pcfproj` ships `PcfBuildMode=production` (G8).
- [ ] **resx:** `<resx version>` bumped on any string/CSS change (G9).
- [ ] **feature-usage:** every `context.webAPI`/`navigation`/`device` call has its `<uses-feature>` (G10).
- [ ] **Xrm:** only via the feature-detected, harness-safe `xrmBridge`; navigation via `context.navigation.*`, never `window.open` (G11).
- [ ] **Wrap:** `FluentProvider`+`IdPrefixProvider` at the root; tokens only, no hardcoded colours.
- [ ] **destroy():** every timer cleared, every subscription/listener removed, `disposed` guards late async.
- [ ] **Bundle budget:** field ≤ 50 KB / dataset ≤ 200 KB; no `@fluentui/react-icons` bundled.
- [ ] **Solution:** control is in a deployed PCF wave (not only its ticket solution); publisher fixed for life.

---

## 9. Open questions for later iterations

- Extract `pcf-core` as a **published npm package** vs a **copied source folder**? (Package = clean
  fixes propagation; folder = zero registry dependency, simpler ALM.)
- Does the template want a **real dataset/grid reference control**, or is a documented stub enough
  until a project needs one? (the live-delivery source has never shipped one.)
- How far to take **`dataverse-gen`** into the PCF layer given the Web API surface is small per
  control — full early-bound, or a hand-curated typed column map?
- A **storybook** proper vs the lean jsdom/`mockPcfContext` harness — is the extra dependency weight
  justified for a Dataverse-embedded control?
