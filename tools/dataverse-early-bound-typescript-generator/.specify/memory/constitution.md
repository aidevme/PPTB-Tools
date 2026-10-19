<!--
Sync Impact Report (remove before committing)
- Version change: template → 1.0.0 (first ratification)
- Principles defined: I. Safe, Previewed Writes; II. dataverse-gen Output Compatibility; III. Documented
  PPTB APIs and a Single-Bundle Build; IV. Strict TypeScript and Clear Layers; V. Tests for New Logic;
  VI. Accessible, Theme-Aware UI; VII. Live Verification and Accurate Docs (template had 5; 7 used)
- Added sections: Technology and Security Constraints; Development Workflow and Quality Gates; Governance with
  an Amendment Log
- Removed sections: none
- Sources: AGENTS.md (sections 2, 3 and 5), the tool's README, the PPTB marketplace and AI-assisted development
  policies, and the aidevme-spec-kit typescript-web profile
- Templates: plan-template.md, spec-template.md and tasks-template.md read the constitution at run time; none
  were changed
- Deferred TODOs: none
-->

# Dataverse Early-Bound TypeScript Generator Constitution

## Core Principles

### I. Safe, Previewed Writes (NON-NEGOTIABLE)

- The tool MUST NOT change Dataverse: it only reads metadata through `dataverseAPI`.
- Nothing is written or deleted on load. Files change only when the user clicks **Generate**, and only what the
  current preview lists.
- Every write is previewed first (the write plan with its `new`, `changed`, `unchanged`, `orphaned` and
  `duplicate` statuses). What Generate writes is decided by `writeStatusOf` / `willWrite` / `writeCounts` in
  `services/plan.ts`, never by counting statuses directly.
- A deletion, or an overwrite the user may not expect, is confirmed in a dialog that names the target folder and
  the number of files, and says plainly that it can't be undone.
- Orphaned files are deleted only when the user has opted in and confirmed the list, and only through
  `deleteOrphanedFiles`, which limits deletion to files inside the output folder.
- Every kind of change the tool makes is listed in the README's `## What this tool changes` section, in the same
  change that introduces it.

Rationale: this is the PPTB marketplace's rule for state-changing tools, and the generator writes into the user's
source tree.

### II. dataverse-gen Output Compatibility (NON-NEGOTIABLE)

- Generated output MUST match dataverse-gen's byte for byte, apart from the deviations listed in the README's
  "Deliberate deviations from dataverse-gen output". `test/generator.test.ts` against `test/reference/` is the
  check.
- A change to generated output updates `test/reference/` and the README's deviations list in the same change, and
  is approved in the spec as a deliberate deviation.
- `.dataverse-gen.json` stays readable and writable by the dataverse-gen CLI: new keys are optional and existing
  keys keep their meaning.
- The templates stay plain functions in `core/templates.ts`: no EJS or other `new Function` at run time (the PPTB
  iframe CSP blocks it). `src/assets/dataverse-gen-templates/*.ejs` stay byte for byte dataverse-gen 2.0.17's.
- `test/reference/` and `test/fixtures/` keep LF line endings.

Rationale: projects switch between this tool and the CLI; any unplanned difference breaks their code or their
diffs.

### III. Documented PPTB APIs and a Single-Bundle Build

- Only methods and parameters documented in the PPTB API reference (`toolboxAPI`, `dataverseAPI`,
  `powerplatformAPI`) are used; a plan that needs another API names the documentation page.
- Every external domain is declared in `cspExceptions` with the reason documented. No environment, user or usage
  data is sent to a publisher endpoint, and there is no telemetry.
- Queries and bulk operations are bounded: paging, batching and loop limits are explicit.
- The build stays one IIFE bundle (`vite.config.ts`: `fixHtmlForPPTB`, `format: 'iife'`,
  `inlineDynamicImports: true`). No code splitting and no ESM output.

Rationale: undocumented APIs break between PPTB releases, and a module or split build doesn't load inside PPTB
even when `npm run dev` works.

### IV. Strict TypeScript and Clear Layers

- `strict` stays on. New code has no `any` and no unchecked `as` casts without a comment saying why.
- `core/` stays pure: no PPTB APIs, no I/O and no DOM UI (`DOMParser` for the CSDL is the only exception).
  `services/` are the PPTB adapters. Components under `components/` other than `apps/App.tsx` are presentational
  and get data and callbacks as props; state lives in `App.tsx` and `hooks/`.
- New exports go through the folder's `index.ts` barrel. Inside `services/`, files import each other directly.
- UI uses Fluent UI v9 with theme tokens, with styles in one `src/styles/<Component>.styles.ts` hook file per
  component.

Rationale: the layers keep the generator testable without PPTB and keep the UI consistent with the other tools.

### V. Tests for New Logic

- Every new function, hook or behavior with logic has a vitest test, named in the tasks.
- A bug fix comes with a test that fails without the fix.
- Tests and reference files MUST NOT be weakened, skipped or regenerated to make a change pass unless the spec
  approves the behavior change.
- `npm run build` (typecheck and bundle) and `npm test` pass after every task; `npm run validate` passes when the
  manifest changes.

Rationale: the reference tests and unit tests are the only automated proof of compatibility and safety; PPTB
can't run in CI.

### VI. Accessible, Theme-Aware UI

- Interactive elements have accessible names, work with the keyboard and have a visible focus state.
- Text and controls meet contrast requirements in PPTB's light and dark themes; colors come from Fluent theme
  tokens, never hard-coded values.
- Animations respect `prefers-reduced-motion`.
- Content that hides or moves keeps its links reachable by keyboard.

Rationale: marketplace policy requires the tool to work in both themes, and every user must be able to reach
every action.

### VII. Live Verification and Accurate Docs

- A feature isn't done until a person has tested it in PPTB against a real Dataverse environment, in light and
  dark themes, including its error paths (missing permissions, expired connection, empty results). The result is
  recorded in `docs/pptb-tools/dataverse-early-bound-typescript-generator/contributing/testing.md` and the tool's
  `TESTING.md`, with the date and the PPTB version.
- The README, the docs pages and the TSDoc change in the same task as the behavior they describe, and
  `npm run docs:api` is rerun (from the repository root) when exported symbols or their TSDoc change.
- Docs, the README and screenshots describe only what the tool does now: no planned features, and no claims
  that weren't verified. Untested behavior is listed as untested.

Rationale: the AI-assisted development policy requires human testing in a real environment, and the README is
what marketplace reviewers check.

## Technology and Security Constraints

- **Stack:** React 18, TypeScript 5.9 (strict), Fluent UI v9 (`@fluentui/react-components`), Vite with the IIFE
  build above, vitest with jsdom. A new runtime dependency needs a reason in the plan, and an existing package that
  does the job is preferred.
- **Dependencies:** `npm audit` reports no high or critical vulnerability in runtime dependencies; build-only
  findings are reviewed in the plan. Unused packages are removed.
- **Secrets:** no keys, tokens, connection strings, environment URLs or tenant names in source, tests, fixtures or
  docs. The tool uses the connection PPTB provides and never builds requests with its own tokens.
- **Ported code:** code and templates derived from dataverse-gen (MIT) keep their notice in
  `THIRD_PARTY_NOTICES.md` and the README's Credits section.
- **AI assistance:** substantial AI-generated code is disclosed in the README's `## AI Assistance` section, and a
  person reviews and tests every code path that writes or deletes files.

## Development Workflow and Quality Gates

- **Spec Kit gates:** the spec is approved before the plan, the plan before the tasks, and the tasks before any
  code. The plan's Constitution Check names each principle that applies and how the plan meets it.
- **Per task:** `npm run build` and `npm test` pass; `npm run validate` when `package.json` changes;
  `npm run lint:tsdoc` reports no new warning; changed Markdown passes `Validate-Markdown.ps1`
  (`aidevme-docs-maintenance`).
- **Commits:** one commit per task, in Conventional Commits format (`CONTRIBUTING.md`), through `aidevme-github`,
  with the task ID in the message. Nothing is pushed without explicit confirmation.
- **Before the pull request:** `/speckit-converge` reports Converged; the live PPTB test (Principle VII) is
  recorded; `intake-policy-review` is run when the change affects what the tool writes, its manifest or its
  network access.
- **Specs:** each `specs/NNN-<feature>/` folder is committed with its code and frozen when the feature merges;
  later changes get a new feature folder.

## Governance

- This constitution governs Spec Kit work on this tool. The repository's `AGENTS.md` still applies; where the two
  differ, the stricter rule wins.
- Plans and pull requests check compliance with every principle. A deviation is allowed only when the plan names
  the principle, explains why, and the user approves it.
- Amendments happen only on an explicit request. Each one updates the version and the Last Amended date and adds
  a line to the Amendment Log.
- Versioning: MAJOR for removing or redefining a principle, MINOR for a new principle or section or materially
  expanded guidance, PATCH for clarifications and wording.

### Amendment Log

- 2026-10-19, 1.0.0: first version, from `AGENTS.md`, the tool's README, the PPTB marketplace and AI-assisted
  development policies, and the `typescript-web` profile.

**Version**: 1.0.0 | **Ratified**: 2026-10-19 | **Last Amended**: 2026-10-19
