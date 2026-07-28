# Unit testing PPTB tools

**Status:** not yet implemented. This document is the plan for adding unit testing to PPTB tools,
starting with `tools/pcf2bpf/` (the only tool implemented so far). There is currently no test suite
or test runner configured anywhere in this repo — per the root `CLAUDE.md`, `npm run build` (`tsc`
typecheck + `vite build`) is the only correctness check today.

## Why now

Multiple real bugs this project has hit so far lived in exactly the kind of code unit tests are best
at catching: `services/formxml.ts`'s per-field entity resolution (a multi-entity Lead → Opportunity
BPF had every field silently attributed to the wrong entity until debugged live against a running
Dataverse environment), and the `loadPublishers`/BPF-scoping FetchXML rewrites in
`services/dataverse.ts`. Both are pure(ish) data-transform code with no UI involved — the kind of bug
a fast, local test would have caught in seconds instead of a live-debugging session.

## 1. Test runner and environment

**Vitest, with the `jsdom` test environment.** React Testing Library / component tests are deferred
to a second pass (see [§2](#2-what-to-test-first)).

- **Vitest over Jest** — Vite is already this tool's bundler. Vitest reuses `vite.config.ts`'s
  resolve/esbuild/TypeScript transform directly, so TS + ESM + `allowImportingTsExtensions` work with
  no extra Babel/`ts-jest` configuration. Jest would need `ts-jest` (or `babel-jest`) plus ESM interop
  work that fights this tool's `moduleResolution: bundler` setup.
- **Version:** pin `vitest@^2.1` to match the currently-pinned `vite@^5.4.11` (Vitest 2.x targets
  Vite 5). Move to Vitest 3 only alongside a future Vite 6 upgrade, not bundled into this work.
- **`jsdom`, not `happy-dom`.** The services layer depends on `new DOMParser().parseFromString(xml,
  "application/xml")` producing a case-sensitive `XMLDocument`, `querySelector("customControl[formFactor]")`
  (mixed-case tags/attributes), and `parsererror` detection. jsdom's XML/`application/xml` handling is
  more spec-compliant than happy-dom's, which has historically been weaker on XML documents and case
  sensitivity — correctness matters more than raw speed here, since XML parsing *is* the code under test.
- **The `iife`/`inlineDynamicImports` build config in `vite.config.ts` does not affect tests.** Those
  settings live under `build.rollupOptions.output` and only apply to `vite build`; Vitest never runs
  the production Rollup build, it transforms modules on the fly. `vitest.config.ts` (or a `test` block
  reusing `vite.config.ts`) can safely coexist with the PPTB-specific build constraints documented in
  the root `CLAUDE.md` without touching them.
- **Why not test components yet:** the components are presentational and testable in principle, but
  the highest-value bugs so far have all been in `services/`, and React Testing Library adds real setup
  cost for this stack specifically — wrapping Fluent UI v9's `FluentProvider`, polyfilling `matchMedia`
  for `main.tsx`'s theme detection, and managing async `act` warnings. Worth a scoped follow-up once
  the services layer has coverage, starting with `hooks/useConnection.ts` (pure logic behind a
  `window.toolboxAPI` stub) rather than Fluent-heavy cards.

### Gotchas already identified

- `docs/pcf2bpf/dataverse/workflow-xaml.xml` is **workflow XAML**, not `systemform.formxml`. Do not
  use it as a `parseFormXml` fixture — it's the wrong artifact entirely (see
  `services/formxml.ts` vs. the never-implemented XAML parsing this repo has only researched).
- `services/metadata.ts` is currently an effectively empty file (1 line) — nothing to test there yet.
- `window.dataverseAPI` is read lazily inside `dataverse.ts`'s internal `api()` helper on every call,
  not captured at import time. This means a mock can be (re-)installed per-test in `beforeEach` with
  no module-reset gymnastics — a deliberate advantage of the existing indirection.

## 2. What to test first

Ranked by value versus effort:

| Rank | Target | Why | Effort |
| --- | --- | --- | --- |
| 1 | `formxml.ts`: `getFieldEntityLogicalName`, `getFieldsForStage`, `getStages` | Pure string/DOM transforms — exactly where the multi-entity resolution bug lived. A real fixture already exists (see [§4](#4-fixture-strategy)). No API mocking needed. | Low |
| 2 | `formxml.ts` mutation functions: `setCustomControl`, `removeCustomControl`, `copyCustomControl`, `getExistingCustomControl`, `hasAnyCustomControl` | Encodes the create/replace/prune logic on `controlDescriptions`; regressions here silently corrupt saved form XML. Still no API mocking. | Low–Medium |
| 3 | `dataverse.ts` pure helpers: `getAttributeTypeLabel`, `getCompatiblePcfControls` | Pure table lookups/filtering, no API calls. `getCompatiblePcfControls`'s "empty array on unknown type" contract is real branching logic worth locking in. | Low |
| 4 | `dataverse.ts` FetchXML-building queries: `loadBpfProcesses` (scoped/unscoped), `loadPublishers`, `loadSolutions`, `loadBpfFormXml` | These build FetchXML strings — the `loadPublishers` rewrite and BPF solution/publisher scoping were both live-debugged this project. Assert on the generated FetchXML shape and on result mapping, via a stubbed `fetchXmlQuery`. | Medium |
| 5 | `pcfManifest.ts`: `parsePcfManifestParameters` | Small, pure DOM parse; cheap enough to fold into the first PR. | Low |
| 6 (deferred) | `hooks/useConnection.ts` | Needs a `window.toolboxAPI` stub plus React Testing Library's `renderHook`. Good second-pass target once the harness exists. | Medium |
| 7 (deferred) | Components (`StagesFieldsCard`, `FormXmlPanel`, etc.) | Fluent UI + provider setup overhead; presentational, lower bug density than the services layer. | High |

The first PR ([§8](#8-first-pr-proof-of-concept-test-cases)) covers ranks 1–3 and 5 — everything with no
mock or a trivial one — to prove the harness before investing in FetchXML-assertion helpers for rank 4.

## 3. Mocking `window.dataverseAPI` / `window.toolboxAPI`

**One shared, typed test-utility factory — never scatter ad-hoc `window.x = {}` casts across test files.**

Create `src/test/apiMocks.ts`:

- `createDataverseApiMock(overrides)` — returns an object typed against `DataverseAPI.API` (from
  `@pptb/types`, declared globally in `node_modules/@pptb/types/dataverseAPI.d.ts`), with a `vi.fn()`
  per method the services actually call: `fetchXmlQuery`, `getEntityMetadata`,
  `getEntityRelatedMetadata`, `update`, `publishCustomizations`. Ship sensible defaults (e.g.
  `fetchXmlQuery` resolving `{ value: [] }`) and let each test override just what it needs via
  `overrides`.
- `installDataverseApi(mock)` — installs the mock via `vi.stubGlobal("dataverseAPI", mock)`, paired
  with `vi.unstubAllGlobals()` in an `afterEach` so nothing leaks between tests.
- `createToolboxApiMock(overrides)` — same pattern for `window.toolboxAPI`, for the eventual
  `useConnection` tests (stubs `connections.getActiveConnection`).

Type the mock against the real interface (not `any`) so it stays honest if the API surface changes —
`fetchXmlQuery`'s `{ value: [...] }` return shape especially.

For FetchXML-assertion tests (rank 4 in §2), prefer parsing the captured argument with `DOMParser` and
querying it over brittle substring matching against whitespace-variable FetchXML strings:

```ts
const fetchXml = mock.fetchXmlQuery.mock.calls[0][0];
const doc = new DOMParser().parseFromString(fetchXml, "application/xml");
expect(doc.querySelector('condition[attribute="componenttype"][value="29"]')).not.toBeNull();
```

## 4. Fixture strategy

**Turn the existing captured form XML into one canonical shared fixture — never paste XML blobs into
individual test files.**

A real, complete, multi-entity fixture already exists: `docs/formxml-visualizer.html`'s `DEFAULT_XML`
constant (lines 132–258) is a genuine Lead → Opportunity sales-process BPF form XML with 4 stages
(Qualify / Develop / Propose / Close). Fields in the Qualify stage carry
`relationship="lk_leadtoopportunitysalesprocess_leadid"`; later stages carry `..._opportunityid` — the
exact shape `getFieldEntityLogicalName` parses, and a ready-made regression fixture for the
multi-entity bug found this session.

- Create `src/test/fixtures/leadToOpportunityFormXml.ts` exporting that XML verbatim as a single
  `const` string, with a header comment noting it's copied from `docs/formxml-visualizer.html` so the
  two don't silently diverge. A `.ts` string export (not a `.xml` file read via `fs`) keeps it in the
  normal module graph — no path/fs juggling, and it matches this repo's "everything is a module with a
  barrel" convention.
- Add hand-crafted micro-fixtures for edge cases the big fixture can't cover, alongside a barrel
  `src/test/fixtures/index.ts`:
  - `formXmlWithMalformedControl` — a minimal `<form>` with one `<control>` missing `datafieldname`
    and one missing `id`, to prove `getFieldsForStage`'s filter drops them and sequence numbering
    stays contiguous.
  - `formXmlWithExistingAssignment` — a minimal form whose one field already has a
    `<controlDescription forControl="..."><customControl formFactor="0">` block, for
    `getExistingCustomControl`/`copyCustomControl`/`removeCustomControl`'s read/prune paths.
  - A `parsePcfManifestParameters` fixture: `<manifest><control><property .../></control></manifest>`
    with one bound, one input, and one nameless property.
- Export a `parse(fixture)` convenience wrapping `parseFormXml` from `src/test/fixtures/index.ts` so
  tests don't re-import `parseFormXml` everywhere just to get a `Document`.

Unifying `docs/formxml-visualizer.html` to import the shared fixture instead of duplicating it is a
reasonable future cleanup, but not required now — the visualizer is a standalone HTML file, and
importing a `.ts` module into it isn't trivial.

## 5. File and directory conventions

Matching this repo's existing patterns (one-thing-per-file `types/`, barrel `index.ts` exports
everywhere, `docs/<tool>/index.md` + `tools/<tool>/README.md` doc split):

- **Co-locate test files with source**: `src/services/formxml.test.ts`,
  `src/services/dataverse.test.ts`, `src/services/pcfManifest.test.ts`. Set
  `test.include = ["src/**/*.test.ts"]` in the Vitest config.
- **Shared test support lives in `src/test/`** (cross-cutting, so not co-located with any one module):
  `src/test/apiMocks.ts`, `src/test/fixtures/` (with its own barrel `index.ts`), and
  `src/test/setup.ts` for anything global (e.g. the `afterEach(() => vi.unstubAllGlobals())`), wired
  up via `test.setupFiles`.
- **TypeScript wiring**: add `"vitest/globals"` to the existing `tsconfig.json`'s `types` array
  (alongside `"@pptb/types"`) so `describe`/`it`/`expect`/`vi` type-check without per-file imports.
  This is simpler than a separate `tsconfig.test.json`; the tradeoff (Vitest globals become visible to
  app code too) is harmless for a repo this size. Revisit only if it causes real confusion.
- `noUnusedLocals`/`noUnusedParameters` are already on in `tsconfig.json` — test files must not leave
  unused imports, same as app code. Since `include: ["src"]` already covers `*.test.ts`, `tsc` will
  type-check tests too (see [§6](#6-packagejson-wiring-and-relationship-to-build) for why that's kept
  as-is rather than excluded).
- **Docs**: this file is the runner-choice rationale and cross-tool guide; add a short "Testing"
  section to `tools/pcf2bpf/README.md` pointing here plus the tool-specific "how to run" commands,
  mirroring the existing `docs/<tool>/index.md` (user-facing) vs. `tools/<tool>/README.md`
  (implementation detail) split.

## 6. package.json wiring and relationship to `build`

Add to `tools/pcf2bpf/package.json`:

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "verify": "tsc && vitest run"
  },
  "devDependencies": {
    "vitest": "^2.1.0",
    "jsdom": "^25.0.0"
  }
}
```

(`@testing-library/react`, `@testing-library/jest-dom`, and `@testing-library/user-event` are deferred
until component tests are actually started — see [§1](#1-test-runner-and-environment).)

**Tests do not block `build`.** `npm run build` stays `tsc && vite build` — fast, dependency-light, and
still usable to produce a `dist/` for manual PPTB debugging even if a test is red. Instead, `npm run
verify` (`tsc && vitest run`) becomes the stated correctness check for changes, superseding the current
`CLAUDE.md` guidance that `npm run build` is the only one. Update `CLAUDE.md` and the
`tester`/`code-reviewer` agent docs accordingly once this lands: run `verify` for correctness, `build`
only when the actual bundle is needed.

There's no repo-wide CI configured yet; if/when CI is added, it should run `npm run verify` per tool
(see [§7](#7-scope-and-rollout-across-multiple-tools) for how that scales past one tool).

## 7. Scope and rollout across multiple tools

This repo's stated philosophy is "each tool is self-contained, no repo-wide build/test command." The
testing setup should respect that, with one light-touch exception.

**Per-tool test config, duplicated — not a shared runtime package.** Each tool keeps its own `vitest`
devDependency, its own Vitest config, its own `test`/`verify` scripts, and its own `src/test/` helpers.
A tool stays buildable, testable, and publishable in isolation, with no cross-tool import and no shared
root `node_modules` dependency — consistent with "each tool has its own package.json/build."

A shared `@pptb-tools/testing`-style internal package was considered and rejected: it would reintroduce
exactly the repo-wide coupling this architecture avoids (a tool could no longer be copied out
standalone; version skew between a shared preset and a given tool's Vite version becomes an ongoing
maintenance tax). The duplication this costs is small — a ~15-line Vitest config plus a generic
`apiMocks.ts` — and is the intended cost of the self-contained model, not an oversight.

To keep that duplication cheap without violating the model:

- Document a copyable **template** in this file (the exact Vitest config + `apiMocks.ts` shape above)
  for a new tool to copy in, since new tools are already scaffolded from samples — "copy this file" is
  the established pattern here, not a shared dependency.
- Optionally, a **root-level convenience script** that loops `tools/*` running each tool's `npm run
  test` is fine as a developer convenience for "test everything at once" — but it must stay clearly
  non-authoritative (each tool remains independently testable on its own) so it doesn't contradict the
  "no repo-wide build" rule.

`apiMocks.ts` is the piece most tempting to share, since the `dataverseAPI`/`toolboxAPI` surface is the
same PPTB platform for every tool. Still, copy it per tool for now — it's small, and tool-specific
stubs tend to diverge in practice. Revisit a shared preset only once enough tools exist to make the
tradeoff worth it; that's a call for a future PR, not this one.

## 8. First PR: proof-of-concept test cases

Scope: the harness itself (config, fixtures, `apiMocks.ts`) plus tests for `formxml.ts` and the pure
parts of `dataverse.ts` (ranks 1–3 and 5 from [§2](#2-what-to-test-first)) — all against the
Lead → Opportunity fixture.

### `src/services/formxml.test.ts`

- **`getFieldEntityLogicalName`**
  - `"lk_leadtoopportunitysalesprocess_leadid"` → `"lead"`
  - `"lk_leadtoopportunitysalesprocess_opportunityid"` → `"opportunity"`
  - `null` → `null`; `""` → `null`
  - a relationship not ending in `id` (e.g. `"lk_foo_bar"`) → `null`
  - regression case: lead-stage and opportunity-stage fields resolve to *different* entities — proving
    fields aren't all silently assigned the BPF's `primaryentity`
- **`getStages(parse(fixture))`** → 4 stages, in document order, names
  `["Qualify", "Develop", "Propose", "Close"]`, ids matching the `<tab id>` GUIDs
- **`getFieldsForStage(doc, qualifyStageId, "lead")`**
  - returns 7 fields, `sequence` exactly `1..7` in order
  - each field's `entityLogicalName === "lead"` — resolved from `relationship`, not the fallback
    (verify by passing a deliberately wrong fallback like `"account"` and asserting it's still `"lead"`)
  - `datafieldname`/`label`/`controlId`/`classId` populated correctly for a spot-checked field (e.g.
    `parentcontactid`, label `"Existing Contact?"`)
- **`getFieldsForStage(doc, developStageId, "lead")`** → 4 fields, all `entityLogicalName ===
  "opportunity"` — the fallback `"lead"` is *overridden* by the `_opportunityid` relationship; this is
  the exact regression case
- **`getFieldsForStage` against `formXmlWithMalformedControl`** — a control missing `datafieldname`
  and one missing `id` are dropped, and surviving valid controls are numbered `1..n` contiguously (no
  gap from the dropped nodes)
- **`getFieldsForStage(doc, "nonexistent-stage", "lead")`** → `[]`
- **`setCustomControl`** (create-from-scratch path, since the base fixture has no
  `controlDescriptions`)
  - after calling for a field on form factor `0`, `getExistingCustomControl(doc, controlId, 0)`
    returns `{ name: pcf.name, parameters: {...} }`
  - a base `<customControl id="{classId}">` with a `<datafieldname>` child is created exactly once
    (call twice for two form factors, assert only one base node exists)
  - `bound`-usage params are skipped; empty/undefined values are skipped; a provided value is written
    with `static="true"` and the `type` attribute from `param.ofType`
  - round-trip: `serializeFormXml(doc)` contains the new `<controlDescription forControl="...">` and
    the param value
  - replace path: calling twice on the same field + form factor with different PCFs replaces (not
    duplicates) the `formFactor` node — exactly one `customControl[formFactor="0"]` under that
    description afterward
- **`copyCustomControl(doc, controlId, 0, 1)`** — with a source on form factor 0 (seeded via
  `setCustomControl` or `formXmlWithExistingAssignment`), clones to form factor 1, overwrites any
  existing target, returns `true`; returns `false` when no source exists
- **`removeCustomControl`** — removes the `formFactor` node; when it was the last one, prunes the
  empty `<controlDescription>`; `hasAnyCustomControl` flips `true` → `false` accordingly
- **`getExistingCustomControl`** against the base fixture (no descriptions at all) → `null`

### `src/services/dataverse.test.ts`

- **`getAttributeTypeLabel`** — `"String"` → `"Single Line Text"`, `"Picklist"` → `"Choice"`, unknown
  `"Foo"` → `"Foo"` (passthrough contract)
- **`getCompatiblePcfControls`**
  - `"String"` against a controls array where one lists `compatibleDataTypes: ["SingleLine.Text"]` and
    one lists `["Whole.None"]` → only the first is returned
  - an attribute type with no mapping (e.g. `"Virtual"`) → `[]` (explicit empty-array contract, not
    "all controls")
  - a control compatible via any one of several listed types is included
- **`loadBpfProcesses`** (with `createDataverseApiMock`)
  - unscoped: `fetchXmlQuery` called with FetchXML containing `category` eq `4`, **no** `distinct`
    and **no** `solutioncomponent` link; result rows mapped to
    `{ workflowid, name, uniquename, primaryentity, xaml }` with `String(...)` coercion (pass a row
    with a numeric/undefined field and assert it becomes a string / `""`)
  - solution-scoped (`{ solutionId }`): emitted FetchXML has `distinct="true"`, a `solutioncomponent`
    link with `componenttype` eq `29`, and a `solutionid` condition (parse-and-query, not substring
    matching)
  - publisher-scoped (`{ publisherId }`): additionally emits a nested `<link-entity name="solution">`
    with a `publisherid` condition
- **`loadBpfFormXml`**
  - resolves `ObjectTypeCode` via `getEntityMetadata(bpf.uniquename, true, ["ObjectTypeCode"])`, then
    queries `systemform` filtered by that numeric code; returns `{ formId, formXml }`
  - throws a clear message when metadata returns no `ObjectTypeCode`
  - throws "No Business Process Flow form was found" when `fetchXmlQuery` resolves `{ value: [] }`
- **`loadSolutions`** — FetchXML asserts all three filter conditions (`isvisible` eq 1, `solutiontype`
  ne 2, `ismanaged` eq 0); a row with `uniquename: "Default"` maps to `isDefaultSolution: true`
- **`loadPublishers`** — FetchXML asserts `distinct="true"` and the inner
  `<link-entity name="solution">` with `isvisible` eq 1; result rows map to the `PublisherInfo` shape

### `src/services/pcfManifest.test.ts`

- Returns only `control > property` entries
- A bound property has `usage: "bound"`; a property with no `usage` attribute defaults to `"input"`
- A nameless `<property>` is filtered out
- `ofType`/`ofTypeGroup` map from `of-type`/`of-type-group`; `required="true"` → `true`
- Malformed XML (`"<not xml"`) and an empty string both → `[]` (the `parsererror`/empty guards)

## Open questions

These need a decision before implementation starts:

1. **Vitest major** — stay on Vitest 2.x against the current Vite 5.4, or bump Vite to 6 + Vitest 3 as
   part of this work? *Recommended: stay on 2.x now; don't couple a Vite major bump to introducing tests.*
2. **`tsc` scope** — should `verify`'s `tsc` pass type-check `*.test.ts` (current `include: ["src"]`
   would), or should tests be excluded via a separate `tsconfig.test.json`? *Recommended: include them
   — free type safety on the mocks — unless it causes real friction.*
3. **`verify` vs. `build` convention** — is it acceptable to update `CLAUDE.md` and the agent docs to
   make `npm run verify` the stated correctness check, leaving `build` as the bundle-only step? This
   changes a documented repo convention.
4. **Shared vs. copied test utilities** ([§7](#7-scope-and-rollout-across-multiple-tools)) — confirm
   "copy per tool, no shared package" is acceptable given the self-contained-tool philosophy, or is
   there appetite for a shared internal preset once a second/third tool exists?
5. **Fixture single-sourcing** — leave `DEFAULT_XML` duplicated between `docs/formxml-visualizer.html`
   and the new fixture (with a provenance comment), or refactor the visualizer to import the shared
   fixture? *Recommended: duplicate now with a provenance comment; unify later.*
6. **Coverage gate** — enforce a coverage threshold from day one, or add `@vitest/coverage-v8` as
   reporting-only first and set thresholds once the suite matures? *Recommended: reporting-only first.*
