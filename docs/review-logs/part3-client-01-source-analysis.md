---
title: "Part 3 · Client-Side Template — Source Comparative Analysis"
author: maciejnowicki
date: 2026-09-10
status: analysis
scope: Client-side (TypeScript web resources / form scripting) templates across CDX, HINT and the live-delivery source
type: source-analysis
feeds: "Build of a new reusable best-in-class client template (NewTemplate)"
---

# Part 3 · Client-Side Template — Source Comparative Analysis

READ-ONLY comparative review of the **client-side** (TypeScript web resources / Dataverse form
scripting) code templates across three sources, to inform a new reusable best-in-class client
template. No source was modified.

## Sources reviewed

| Ref | Path | What it is |
|-----|------|-----------|
| **CDX** | `C:\Repos\HSO-Power Platform Pipeline Template - CDX\Power Platform Pipeline Template - CDX\Client\clientjs` | A real, complete TypeScript client project: `dataverse-gen` early-bound types, webpack bundling, jest + xrm-mock tests, a **JSON-driven client Rule Engine**, PowerShell web-resource push. |
| **HINT** | `C:\Repos\HINT-Pipelines\ProjectTemplate\Client\clientjs` | A copy of CDX. **Byte-identical** to CDX (`diff -rq` excluding `node_modules/`, `coverage/`, `dist/`, `package-lock.json` returned **no differences**). Same `package.json`, `webpack.*`, `tsconfig.json`, `powerPlatform.config.template.json`, `src/`, `README.md`. HINT additionally ships a skill (below). |
| **live-delivery source** | `C:\Repos\workspace\NewHorizon-App-SalesAI-CRM` | Two realities: (a) an **unused** TS+Webpack scaffold at `WebResources/hso_/` with an **empty webpack `entry:{}`**, and (b) the **actual production form scripts** — hand-authored **ES5 JavaScript** at `SourceCode/WebResources/hso_/scripts/incident/*.js`. |

Skills also read:
- **HINT** `.claude/skills/hso-client-ruleengine/SKILL.md` — documents how to drive the CDX Rule Engine.
- **live-delivery source** `.claude/skills/hso-formscript-development/SKILL.md` — documents the live-delivery source's ES5 namespace pattern, Client API discipline, and Solution Checker rule list (defers to SOP `webresource-development/webresource-best-practices.md`).

> **Key framing:** CDX and HINT are the *same* template. The real comparison is **CDX/HINT (TS-first, Rule-Engine-driven)** vs **live-delivery source (ES5, hand-authored, Solution-Checker-disciplined)**. Maciej explicitly wants to standardise on **TypeScript** (per project memory `form-scripts-are-plain-js`).

---

## 1. How each does client-side

| Dimension | CDX / HINT | live-delivery source (actual, ES5) | live-delivery source (scaffold, unused) |
|-----------|-----------|---------------------|--------------------------|
| **Language** | TypeScript 5.3, `strict` (huge 12 KB `tsconfig.json`) | Hand-authored **ES5** (`var`, IIFE, `"use strict"`) | TypeScript 5.4, `strict`, `noImplicitAny`, `strictNullChecks` |
| **Early-bound types** | **`dataverse-gen` 2.0.15** → `src/dataverse-gen/` (Account, Contact entities + enums + `metadata.ts`), config in `.dataverse-gen.json`; also `dataverse-ify` + `dataverse-auth` deps | None | None (only `@types/xrm`) |
| **Bundling** | webpack 5, `webpack.common/dev/prod.js` merged via `webpack-merge`; **single entry** `./src/index.ts` → one bundle `HSO_Customer_clientHooks.js`; `libraryTarget: "var"`, `library: ["hso","CustomerClientHooks"]` | **None** — scripts ship as raw `.js` bytes, deployed as-is | webpack 5, **multi-entry** (one entry per web resource), `library:{type:'assign-properties', name:'HSO'}`, Terser; **`entry:{}` is empty** so build is a no-op by design |
| **Types/Xrm** | `@types/xrm` 9.0.88 | `@types/xrm` (skill-guided) | `@types/xrm` 9.0.79 |
| **Lint / format** | ESLint (`@typescript-eslint/recommended` + `prettier`) + Prettier (`printWidth:120`, `semi`, `trailingComma:all`); `camelcase` relaxed for `lin_`/prefixes | ESLint per SOP §16/§17 (Solution Checker rule set); enforced by review, not wired into this folder | ESLint script present (`eslint src/**/*.ts`) |
| **Testing** | **jest 29 + ts-jest + xrm-mock 3.5.9**; `collectCoverage:true`; thresholds **branches 70 / functions 95 / lines 90 / statements 70**; `coverage/` (lcov + html) committed; ~25 test files across RuleEngine core/processors/utils | **`test/smoke.js`** — a bespoke Node `vm`-sandbox harness that runs the *shipped* ES5 file with a stubbed `Xrm`, asserting Maia/non-Maia paths (10 assertions). No jest. | None |
| **Form-event registration model** | One class per form (`src/Forms/Account/AccountForm.ts`), static `onFormLoad(executionContext)`. All classes re-exported from `src/index.ts`. Registered in D365 as `hso.CustomerClientHooks.AccountForm.onFormLoad`, pass-execution-context = yes. `formName` passed **explicitly** (never `ClassName.name`, which webpack minifies). | Namespace-IIFE pattern: `var HSO = window.HSO||{}; HSO.IncidentStatusReason = …; (function(){ "use strict"; this.onLoad = …; }).call(HSO.IncidentStatusReason);` Registered as `HSO.IncidentStatusReason.onLoad`. | Same namespace intent, but via webpack `assign-properties` onto `window.HSO` |
| **Business-rules approach** | **JSON-driven Rule Engine** (see §Rule Engine below). Logic lives in JSON, not code. | Imperative TS/JS in the handler (e.g. `removeOption`, `addOnChange`, `setVisible`, `setRequiredLevel`, `Xrm.WebApi`) | n/a |
| **Folder structure** | `src/Forms/<Entity>/<Form>.ts`, `src/Rules/<Entity>/<Form>/<form>.json`+`.xml`, `src/RuleEngine/` (core/processors/types/utils/`__tests__`), `src/Helpers/` (Logger, dataverse-init), `src/dataverse-gen/`, `Scripts/`, `config/` | `scripts/<entity>/<entity>_<purpose>.js` mirroring the web-resource name so the deploy script can infer it | `src/<entity>/<form>.ts` intended |
| **Config templating** | `powerPlatform.config.template.json` → copy to git-ignored `powerPlatform.config.json`; declares `environmentUrl`, `solutionName`, `webResourcePrefix`, and a `deployment` map (clientHooks bundle + per-form rule JSON/XML web-resource names/display names). `config/test.yaml` for dataverse-auth. | None — deploy via skill `Deploy-WebResource.ps1` / `Register-FormHandler.ps1`, path-inferred | None |
| **Deployment** | `Scripts/push-webresources.ps1` (+ `.cmd` launcher): builds (`npm run build`), connects via `Microsoft.Xrm.Data.PowerShell`, pushes the JS bundle + each rule JSON/XML into the configured solution | Skill `Deploy-WebResource.ps1`; `Register-FormHandler.ps1` wires handlers onto forms (per memory) | — |

### The CDX/HINT client Rule Engine (the standout asset)

A genuinely well-engineered, declarative form-logic engine. `RuleEngine.initialize(executionContext, {formName})`:

1. **`ConfigurationLoader`** auto-detects entity + form, builds a web-resource path
   (`{prefix}/Rules/<Entity>/<Form>/<form>.json` and `.xml`), and loads JSON rules + FetchXML
   templates **in parallel** (`Promise.all`). `formName` override handles Quick Create (where the
   form label isn't reliably available).
2. **Privilege gate** (`PrivilegeUtils`) can exclude whole configs or individual rules by security role.
3. **Five rule processors**, executed in a fixed order, each isolated in its own try/catch:
   `ConcatenationRule` → `CopyLookupValueRule` → `FormComponentRule` (visibility/readonly/required on
   fields/tabs/sections) → `OptionSetFilterRule` → `LookupFilterRule` (FetchXML-templated lookup filtering).
4. **`ErrorHandler`** (collects + surfaces a form-notification summary), **`PerformanceMonitor`**
   (per-operation timing, gated by config), and a **`cleanup()`** that clears handlers + caches.
5. Rules are plain JSON with `ruleOrder`, `enabled`, `filter` (operators `eq/ne/gt/lt/gte/lte/contains/in/…`,
   sources `self`|`<lookupField>`), and reactive `onChange` re-evaluation.

The HINT skill adds the critical operational rule the engine does **not** enforce itself:
**every hide/require/disable FormComponentRule MUST be paired with its inverse show/unrequire/enable rule**
(a single-direction rule silently leaves the field hidden for all other values). It also documents what
the engine deliberately does **not** cover (notifications, save-time validation, Custom API calls, ribbon
logic) — those stay as custom TS in the handler.

---

## 2. Strengths & weaknesses (concrete)

### CDX / HINT
**Strengths**
- TypeScript-first with **early-bound types** (`dataverse-gen` — `src/dataverse-gen/`), giving compile-time
  safety and IntelliSense on entity fields, not just `@types/xrm`.
- **Real automated tests** with enforced coverage thresholds (`jest.config.js`) and committed `coverage/`.
- The **Rule Engine** turns most routine form logic (visibility/required/lookup filtering/value copying)
  into reviewable JSON — less bespoke code, consistent behaviour, per-role gating, perf + error reporting
  built in. Clean separation: `Forms/` handlers are boilerplate, `Rules/*.json` holds logic.
- Config templating (`powerPlatform.config.template.json`) + a repeatable push script.
- Sensible webpack dev/prod split with source maps in dev.

**Weaknesses**
- **`Logger` writes via `console.log/warn/error`** (`src/Helpers/Logger.ts`). This **violates the live-delivery source's
  Solution Checker `remove-console` (Medium)** — a real blocker in Managed Environments. The engine is
  otherwise clean but this must be swapped for a no-console sink before adoption.
- **Single-bundle, `libraryTarget:"var"`** (`webpack.common.js` → `library:["hso","CustomerClientHooks"]`).
  One bundle per project carrying all handlers is fine *only because it's one bundle*; the moment a second
  independently-built `var`-library bundle lands on the same form it would **clobber the global** — exactly
  the trap the live-delivery source's scaffold calls out and fixes with `assign-properties`.
- `dataverse-gen` output is **committed and stale-prone** (only `account`+`contact` generated); needs a
  regen discipline.
- `config/test.yaml` and `powerPlatform.config.template.json` carry sample org URLs / placeholders — must be
  scrubbed per project.
- CDX and HINT being **identical duplicates** is itself a maintenance smell (two copies to keep in sync).

### The live-delivery source (actual ES5)
**Strengths**
- **Solution-Checker-disciplined** and 100%-upgradeable: `formContext` (never `Xrm.Page`), **no DOM/jQuery/eval/
  sync-XHR/console**, `===`, `"use strict"`, `Xrm.Navigation` for dialogs — codified in the
  `hso-formscript-development` skill and its SOP.
- **Excellent, contract-accurate header comments** (e.g. `incident_statusreason.js` explains *why* a
  hard-coded hidden-reason list, *why* re-apply on `statecode` change, and the fail-open guarantee).
- **Fail-open** everywhere (a picker quirk never blocks a Case load).
- The **`assign-properties` webpack insight** (in `WebResources/hso_/webpack.config.js`) is the correct
  multi-bundle namespace-merge fix and is well-documented.
- The **smoke harness** (`test/smoke.js`) tests the *exact shipped bytes* in a Node `vm` sandbox.

**Weaknesses**
- **ES5, no types, no early-bound** — field names are bare strings; no compile-time safety; refactoring is
  manual. This is precisely what Maciej wants to move off.
- **TS scaffold is inert** (`entry:{}`), so it provides *no* current value — it's aspiration, not capability.
- **No jest/xrm-mock**; the smoke harness is bespoke and per-script (doesn't scale to a suite).
- **No declarative rule engine** — every visibility/required/filter rule is hand-written imperatively and
  re-implemented per form.
- No config templating; deployment relies on skill scripts + path inference.

---

## 3. Gaps (each vs the others)

- **The live-delivery source lacks:** TypeScript build that actually runs, early-bound types (`dataverse-gen`), a jest/xrm-mock
  suite with coverage, a declarative rule engine, and config templating. It *has* the Solution-Checker
  discipline and the `assign-properties` fix that CDX lacks.
- **CDX/HINT lack:** Solution-Checker-clean logging (their `Logger` uses `console.*`), the multi-bundle-safe
  `assign-properties` output (they use clobber-prone `var`), the explicit "no DOM/jQuery/sync-XHR/`==`/`console`"
  discipline written down, and fail-open header-comment culture. They also carry **duplicate** template
  copies and sample credentials/URLs.
- **Both lack (relative to a best-in-class target):** a single canonical, de-duplicated template; a documented
  `dataverse-gen` regeneration step; and an ESLint config that *encodes the Solution Checker rules* so the
  console/`==`/DOM violations fail at lint time rather than at import.

---

## 4. Best-in-class recommendation (target client template)

**TypeScript-first, Rule-Engine-driven, Solution-Checker-clean.** Take the CDX/HINT engine and toolchain as
the spine, and fold in the live-delivery source's discipline and packaging fixes. This supersedes the live-delivery source's plain-ES5 reality
(which Maciej explicitly wants to retire) *without losing* what makes the ES5 scripts safe.

Adopt:
1. **TypeScript 5.x `strict`** + **`dataverse-gen` early-bound types** (`.dataverse-gen.json`, output under
   `src/dataverse-gen/`), with a documented **regeneration step** and generated files treated as
   build-artifacts-that-happen-to-be-committed.
2. **webpack (dev/prod via `webpack-merge`)** — **but use the live-delivery source's `library:{type:'assign-properties', name:'HSO'}`**
   instead of CDX's `libraryTarget:"var"`, so multiple HSO bundles on one form merge rather than clobber.
   Single-entry (all handlers via `index.ts`) is fine within one project; the `assign-properties` output makes
   it safe even if a second bundle ever co-exists. Terser in prod, source maps in dev.
3. **ESLint + Prettier that encode the Solution Checker rule list** (from the live-delivery source's SOP §16/§17): forbid `console.*`,
   `eval`/`new Function`/string-`setTimeout`, sync `XMLHttpRequest`, `window.top`/`window.parent`, `with`,
   `innerHTML`, `document.write`, `==`/`!=`, `debugger`, absolute Dataverse URLs. **Fix CDX's `Logger` to a
   no-console sink** (buffer + optional `Xrm.Navigation`/form-notification surface, or strip in prod build) so
   it passes Checker.
4. **jest + ts-jest + xrm-mock** with coverage thresholds (start at CDX's 70/95/90/70). Port the RuleEngine's
   `__tests__` wholesale; add form-handler tests via xrm-mock.
5. **The client Rule Engine — keep it, it earns its place.** It removes a whole class of bespoke per-form code
   and standardises behaviour, privilege gating, error and perf reporting. Ship it as `src/RuleEngine/` (engine
   frozen, per the skill), with `src/Forms/<Entity>/<Form>.ts` boilerplate handlers and `src/Rules/<Entity>/<Form>/`
   JSON+XML. **Bake in the paired-inverse-rule invariant** (from `hso-client-ruleengine`) as a lint/validation
   check on the rule JSON, not just documentation. Keep the "not covered by the engine" list (notifications,
   save-time validation, Custom API, ribbon) as custom-TS guidance.
6. **Solution-Checker-compliant patterns from the live-delivery source**: `formContext` over `Xrm.Page`; namespace pattern;
   **fail-open** OnLoad; contract-accurate header comments; `Xrm.WebApi` with `$select` discipline.
7. **Web-resource ↔ Dataverse-name mapping**: keep the **local folder mirrors the web-resource name** rule
   (live-delivery source) so deployment can infer names, *and* the explicit `deployment` map in
   `powerPlatform.config.template.json` (CDX) for the bundle + per-form rule files. Names:
   `{prefix}_/scripts/<entity>/<entity>_form.js` for handlers, `{prefix}_/Rules/<Entity>/<Form>/<form>.json|.xml`
   for rules, one client-hooks bundle `{prefix}_/js/clientHooks`.
8. **Build-output deployment**: `npm run build` → `dist/<prefix>_clientHooks.js` → pushed by the config-driven
   PowerShell (CDX `push-webresources.ps1`) or the live-delivery source's deploy skill, into the ticket/wave solution. Template
   config file is `*.template.json` → copied to a git-ignored real config (no committed URLs/credentials).

**How it supersedes the live-delivery source's ES5:** existing ES5 scripts are re-expressed as (a) JSON rules where they're
visibility/required/lookup-filter/copy/concatenation logic — which covers most of them — or (b) typed TS
handlers where they're imperative (like `incident_statusreason.js`'s `removeOption` + `statecode` re-apply,
which would be a small typed handler, not a rule). The result keeps every safety property the ES5 scripts have
(fail-open, no-console, `formContext`) while adding types, tests, and declarative logic.

---

## 5. Things the user may have missed (worth keeping)

A brief focused only on "port the form scripts to TypeScript" would likely overlook these high-value assets:

- **The client Rule Engine itself.** It's the single biggest asset here — a maintained, tested, JSON-driven
  form-logic engine with privilege gating, ordered processors, error + perf reporting, and a companion skill.
  Rebuilding form logic imperatively in TS would throw this away.
- **`dataverse-gen` early-bound types.** Not just `@types/xrm` — actual generated entity/enum types. Turns
  string field names into checked symbols. Needs a regen discipline to stay useful.
- **jest + xrm-mock with enforced coverage** (and the committed `coverage/` lcov/html). A real test culture
  already exists in CDX; adopt it rather than reinvent the bespoke smoke harness.
- **Config templating** (`powerPlatform.config.template.json` + `config/test.yaml`) — the `*.template.json` →
  git-ignored-real pattern keeps env URLs/credentials out of source.
- **The live-delivery source's `assign-properties` webpack fix** — subtle but important; the "obvious" `var` library (CDX) is the
  wrong default when two HSO bundles can share a form.
- **The paired-inverse-rule invariant** from `hso-client-ruleengine` — a non-obvious correctness rule that
  belongs in tooling.
- **The live-delivery source's Solution-Checker rule list + fail-open + comment-accuracy culture** — the discipline that keeps
  form scripts 100% upgradeable and import-safe. The CDX engine must be brought up to this bar (the `console.*`
  logger is the one concrete gap).

---

## Recommended client structure (target)

```
Client/clientjs/
├── package.json                 # TS, webpack, jest, xrm-mock, dataverse-gen, eslint+prettier
├── tsconfig.json                # strict
├── .dataverse-gen.json          # entities/enums to generate (regen step documented)
├── .eslintrc.json               # encodes Solution Checker rules (no console/eval/==/DOM/sync-XHR…)
├── .prettierrc.json
├── jest.config.js               # ts-jest + coverage thresholds (70/95/90/70)
├── webpack.common.js            # entry ./src/index.ts; library {type:'assign-properties', name:'HSO'}
├── webpack.dev.js / webpack.prod.js   # merge; source maps (dev) / Terser (prod)
├── powerPlatform.config.template.json # env URL, solution, prefix, deployment map (→ git-ignored real)
├── Scripts/
│   ├── push-webresources.ps1    # build + push bundle + rule JSON/XML into solution
│   └── deploy-clienthooks.cmd
├── config/
│   └── test.yaml                # dataverse-auth (no real creds committed)
└── src/
    ├── index.ts                 # re-exports all Forms handlers (+ RuleEngine, Logger, CONFIG)
    ├── config.ts                # centralized CONFIG (prefix, log level, thresholds)
    ├── Helpers/
    │   ├── Logger.ts            # ⚠ NO-console sink (Checker-clean) — not raw console.*
    │   └── dataverse-init.ts
    ├── dataverse-gen/           # generated early-bound entities + enums + metadata
    ├── Forms/
    │   └── <Entity>/<Form>.ts   # boilerplate handler → RuleEngine.initialize({formName})
    │                            #   or a typed imperative handler where the engine doesn't cover it
    ├── Rules/
    │   └── <Entity>/<Form>/
    │       ├── <form>.json      # declarative rules (paired-inverse invariant validated)
    │       └── <form>.xml       # FetchXML templates for lookup filters
    └── RuleEngine/              # engine (frozen): core/ processors/ types/ utils/ __tests__/
```

## Decision table

| Concern | Chosen approach | Source | Why |
|---------|-----------------|--------|-----|
| Language | TypeScript 5.x `strict` | CDX/HINT | Compile-time safety; Maciej's explicit direction to standardise on TS |
| Early-bound types | `dataverse-gen` → `src/dataverse-gen/` | CDX/HINT | Checked field names, not string literals; beyond `@types/xrm` |
| Bundling | webpack dev/prod via `webpack-merge` | CDX/HINT | Proven split, source maps in dev, Terser in prod |
| Bundle global | `library:{type:'assign-properties', name:'HSO'}` | **live-delivery source** | Merges bundles on a shared form; avoids CDX `var` clobber |
| Lint/format | ESLint+Prettier **encoding Solution Checker rules** | live-delivery source SOP + CDX config | Fails console/`==`/DOM/eval/sync-XHR at lint, not at import |
| Logging | No-console sink (replace CDX `Logger`) | live-delivery source rule + CDX shape | `remove-console` is a Managed-Env blocker; keep the leveled API |
| Testing | jest + ts-jest + xrm-mock + coverage thresholds | CDX/HINT | Real suite already exists; enforceable coverage |
| Form logic | JSON-driven **Rule Engine** + typed handlers for the rest | CDX/HINT + skill | Removes bespoke per-form code; standardises behaviour/gating |
| Rule correctness | Paired-inverse-rule check on rule JSON | HINT skill | Single-direction rule is a silent bug; enforce in tooling |
| Handler pattern | `Forms/<Entity>/<Form>.ts` static `onFormLoad`, explicit `formName` | CDX/HINT | Minification-safe; boilerplate handler, logic in JSON |
| Client API discipline | `formContext`, no DOM/jQuery, fail-open, `Xrm.Navigation` | **live-delivery source** | 100% upgradeable, import-safe |
| WR ↔ Dataverse names | Folder mirrors WR name + explicit `deployment` map | live-delivery source + CDX | Deploy can infer names; map covers bundle + rule files |
| Config templating | `*.template.json` → git-ignored real config | CDX/HINT | Keeps env URLs/creds out of source |
| Deployment | build → `dist/*clientHooks.js` → config-driven PS push into solution | CDX/HINT (+ live-delivery source skill) | Repeatable, solution-scoped |
| Comment/doc discipline | Contract-accurate, "why" header comments | **live-delivery source** | Matches CLAUDE.md comment-accuracy rule |
| Canonical copy | One de-duplicated template | (fix of CDX==HINT dup) | Two identical copies is a sync liability |
