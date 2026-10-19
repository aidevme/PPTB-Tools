# Implementation Plan: Custom enum template for duplicate identifiers

**Branch**: `features/dataverse-early-bound-typescript-generator` (Spec Kit feature `001-duplicate-identifier-templates`)
| **Date**: 2026-10-19 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-duplicate-identifier-templates/spec.md` (approved 2026-10-19)

## Summary

When a preview finds enum files with duplicate identifiers, the Preview card proposes a **Custom enum template**. The
proposal turns on a new tool setting, `customEnumTemplate`. With it on, the tool renames later duplicates in its own
output with the existing rule (`<Name>_<Value>`), and Generate writes a custom `enum.ejs` (a variant of dataverse-gen's,
applying the same rule) to the project's `templateRoot`, so the dataverse-gen CLI produces the same names. Nothing is
written until the next preview and Generate. By default nothing changes. A test renders the custom template with the
real EJS engine and compares it with the tool's output to prove the names match.

## Technical Context

**Language/Version**: TypeScript 5.9 (strict), React 18

**Primary Dependencies**: Fluent UI v9 (`@fluentui/react-components`, `@fluentui/react-icons`); new devDependency
`ejs@3.1.10`, imported only by a test (research R3)

**Storage**: the tool's PPTB settings (`toolboxAPI.settings`, key `toolConfig`) for the new setting; project files
through the existing write plan (`_templates/enum.ejs`)

**Testing**: vitest with jsdom (`npm test`); `npm run build` (tsc + Vite); `npm run lint:tsdoc`

**Target Platform**: Power Platform ToolBox desktop (Electron iframe, single IIFE bundle); minAPI 1.2.7

**Project Type**: desktop tool (PPTB add-in), single project

**Performance Goals**: no measurable change; renaming and template selection are linear in the number of enum members

**Constraints**: no EJS at run time (PPTB CSP); `src/assets/dataverse-gen-templates/` stays byte for byte; default
output unchanged; no write without a preview

**Scale/Scope**: one new setting, one new template asset, one proposal, about 10 source files and 4 docs pages

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design: still passing.*

| Principle | How the plan meets it |
| --- | --- |
| I. Safe, Previewed Writes | Accepting only saves a setting and marks the preview stale (FR-004). The custom `enum.ejs` goes through the write plan like every template, so it's listed (`changed`/`new`) before Generate writes it. Nothing is deleted. The README's "What this tool changes" gains the custom template (it replaces an existing `enum.ejs`). |
| II. dataverse-gen Output Compatibility | Default output and templates are unchanged (FR-001); the reference tests still pass untouched. The renamed output is an opt-in deviation, added to "Deliberate deviations". The originals in `src/assets/dataverse-gen-templates/` aren't touched; the custom file lives in `src/assets/custom-templates/`. `.dataverse-gen.json` is unchanged (the setting is a tool setting). No EJS at run time. |
| III. Documented APIs, single bundle | No new PPTB API; only `toolboxAPI.settings` as today. No new domain, no telemetry. `ejs` is a devDependency used by one test, so it never enters the IIFE bundle. |
| IV. Strict TypeScript, clear layers | The rename decision stays in `core/generator.ts` (pure); template selection in `services/dataverseGenTemplates.ts`; settings in `config/` and `hooks/`; the proposal is presentational in `components/cards/`, with state in `App.tsx`/hooks. Shared label and explanation in `components/shared/settingsInfo.tsx`. |
| V. Tests for New Logic | Tests for: config merge/default, template selection, rename-when-either-setting, plan statuses, the proposal (shown, Not now, accept, hidden without duplicates), the Settings switch, and the EJS equivalence contract. No reference file changes. |
| VI. Accessible, Theme-Aware UI | Fluent `MessageBar` with a title and two buttons; theme tokens only; keyboard reachable; the disabled Rename switch says why. |
| VII. Live Verification and Accurate Docs | [quickstart.md](./quickstart.md) is the live test, recorded in `testing.md`/`TESTING.md`. README, user guide, Settings/Preview component pages, schema description, TSDoc and `npm run docs:api` change in the same tasks. |
| Technology and Security Constraints | New devDependency `ejs@3.1.10` (Apache-2.0, depends on `jake`), test-only, justified in R3; `npm audit` reviewed. The custom template derives from dataverse-gen (MIT): notice kept in `THIRD_PARTY_NOTICES.md`. |

No violations; Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-duplicate-identifier-templates/
├── spec.md
├── plan.md                         # this file
├── research.md                     # Phase 0
├── data-model.md                   # Phase 1
├── quickstart.md                   # Phase 1: automated and live validation
├── contracts/
│   ├── custom-enum-template.md     # the template's interface to the dataverse-gen CLI
│   └── preview-proposal.md         # the proposal and the setting in the UI
├── checklists/requirements.md
└── tasks.md                        # /speckit-tasks (not created here)
```

### Source Code (tool folder)

```text
tools/dataverse-early-bound-typescript-generator/
├── src/
│   ├── assets/custom-templates/enum.ejs            # NEW: dataverse-gen's enum.ejs + the renaming loop
│   ├── config/
│   │   ├── index.ts                                # customEnumTemplate in ToolConfig, defaults, mergeToolConfig
│   │   └── dataverse-early-bound-typescript-generator-config(.json|.schema.json|.sample.json)
│   ├── core/generator.ts                           # TSDoc fix on renameDuplicateEnumMembers (string enums)
│   ├── services/dataverseGenTemplates.ts           # dataverseGenTemplateFiles(config, { customEnum })
│   ├── hooks/
│   │   ├── usePreviewGenerate.ts                   # rename = rename || customEnumTemplate; customEnum templates
│   │   ├── useToolSettings.ts                      # 'customEnumTemplate' as a preview setting; stale on change
│   │   └── useSettingsDraft.ts                     # draft/defaults include the new key
│   ├── components/
│   │   ├── shared/settingsInfo.tsx                 # CUSTOM_ENUM_TEMPLATE_TITLE / _INFO
│   │   ├── cards/PreviewCard.tsx, PreviewParts.tsx # proposal + switch; Rename disabled while custom is on
│   │   ├── panels/SettingsPanel.tsx                # switch in the Duplicate identifiers card
│   │   └── apps/App.tsx                            # wires the setting into the Preview card
│   └── styles/PreviewCard.styles.ts                # only if the proposal needs spacing
├── test/
│   ├── customEnumTemplate.test.ts                  # NEW: EJS equivalence contract (uses ejs)
│   ├── dataverseGenTemplates.test.ts               # template selection
│   ├── duplicateIdentifiers.test.ts                # proposal UI, rename via either setting
│   ├── hooks.test.ts, settings.test.ts             # setting, stale preview, Settings switch
├── README.md                                       # What this tool changes, Deliberate deviations, Credits
├── THIRD_PARTY_NOTICES.md                          # the modified enum.ejs
└── package.json                                    # devDependency ejs
.gitattributes (repo root)                          # -text for src/assets/custom-templates/*.ejs
docs/pptb-tools/dataverse-early-bound-typescript-generator/
├── guide/tool-settings.md, guide/troubleshooting.md, guide/what-gets-generated.md
├── components/cards/preview-card.md, components/panels/settings-panel.md
└── contributing/testing.md (live results)
```

**Structure Decision**: the existing single-project layout; no new folders besides `src/assets/custom-templates/`.

## Decisions

- **D1 (research R3): `ejs` as a test-only devDependency.** It's the only way to check the custom template the way the
  CLI runs it. Earlier the tool deliberately avoided installing `ejs` for **run time**; this is different (never
  bundled, never runs in PPTB), but it is a new package, so it's called out for approval here.
- **D2 (R5): a separate `customEnumTemplate` setting**, with renaming derived from either setting, so turning the
  template off restores the default output.
- **D3 (R1): no special handling for string-valued enums** (they can't have duplicates); the misleading TSDoc on
  `renameDuplicateEnumMembers` is corrected.

## Complexity Tracking

None.

## Amendment 1: confirm before overwriting an edited `enum.ejs` (2026-10-19)

Spec: US1 scenario 6, FR-012, SC-005.

**Detecting an edited file** (pure, in `services/dataverseGenTemplates.ts`): `editedEnumTemplate(plan)` returns the
plan's `<templateRoot>/enum.ejs` entry when its `existingContent` is neither dataverse-gen's `enum.ejs` nor
`CUSTOM_ENUM_TEMPLATE` (line endings ignored, as the write plan compares), otherwise `undefined`. A plan without
templates (Generate templates off) or without an existing `enum.ejs` gives `undefined`.

**Asking** (shared by both entry points):

- **Preview card** (proposal and switch): `App.tsx` routes `onCustomEnumTemplateChange(true)` through a small hook,
  `useCustomEnumTemplateConfirmation(plan, generateTemplates, save)`. When `editedEnumTemplate(plan)` finds a file it
  opens a `ConfirmationDialog` instead of saving; **Use custom enum template** saves, **Cancel** closes it. Turning
  the setting off saves straight away.
- **Settings panel**: a new optional prop `editedEnumTemplatePath` (from `editedEnumTemplate(plan)` in `App.tsx`).
  On **Save**, when the draft turns `customEnumTemplate` on, Generate templates is on in the draft, and the prop is
  set, the panel opens the same dialog before calling `onSave`; **Cancel** returns to the panel with the draft
  unchanged and nothing saved.

**Dialog** (reuses `components/dialogs/ConfirmationDialog.tsx`): title "Replace your edited enum.ejs?"; message with
the file's path, that it differs from dataverse-gen's template and so looks edited, that the next Generate replaces it
with the custom template and the edits are lost unless they're in source control, and that nothing is written now;
confirm **Use custom enum template**, cancel **Cancel**. Wording and the shared message live in
`components/shared/settingsInfo.tsx` so both places say the same.

**Constitution re-check:** I is strengthened (a confirmation naming the file before an overwrite); II–VI are
unchanged (no new API, dependency or output change; the dialog is a Fluent `Dialog` with keyboard access); VII adds
the dialog to the docs and to the live test (quickstart step 3).

## Amendment 2: the custom enum template per project (2026-10-19)

Spec: FR-009, FR-010, FR-012 (Options card entry point), US3 scenarios 1–2, Key Entities.

**Storage (D4):** a tool-namespaced object in `.dataverse-gen.json`, so it can't collide with a future dataverse-gen
key: `"pptbEarlyBoundGenerator": { "customEnumTemplate": true }`. `DataverseGenConfig` already keeps unknown keys, and
the dataverse-gen CLI 2.0.17 writes the whole object back (`saveConfig`), so the key survives it. A missing object or
key means "use the default"; a non-boolean value is ignored. Read and written with two small pure helpers in
`core/config.ts` (`projectCustomEnumTemplate(config)`, `withProjectCustomEnumTemplate(config, value)`).

**Default (D5):** the tool setting moves from `ToolConfig.customEnumTemplate` to
`ProjectDefaults.customEnumTemplate` (Settings → Options → Generated files card, default `false`). Unlike the other
Options, it's applied only when the project's file has no value: `applyProjectDefaults` fills it in, never replaces
it, so a project keeps its own choice when it's reopened or when the default changes. The old top-level
`ToolConfig.customEnumTemplate` (never released) is dropped; `mergeToolConfig` ignores it.

**Effects:**

- `usePreviewGenerate` reads the project's value instead of the tool setting (renaming when Rename or it is on; the
  custom `enum.ejs` when it and Generate templates are on).
- The proposal, the Preview card switch and a new Options card switch change the project's value through
  `useProject.updateConfig`, which marks the preview stale; Generate saves it with the rest of `.dataverse-gen.json`.
  `customEnumTemplate` leaves `PreviewSettingKey`.
- Amendment 1's confirmation stays on the proposal and the Preview card switch (`useCustomEnumTemplateConfirmation`,
  now saving to the project) and moves from the Settings panel's Save to the Options card switch. Settings → Options
  only changes the default for projects without a value, so it never overwrites anything and doesn't ask; its
  `editedEnumTemplatePath` prop and the Save confirmation are removed.
- The Settings panel's Generate & files tab loses the Custom enum template row, and Rename is no longer shown as
  disabled there (Rename is tool-wide, the custom template per project); on the Preview card, Rename still shows on
  and disabled while the open project uses the custom template.

**Constitution re-check:** I unchanged (no new write; the value is saved by Generate with `.dataverse-gen.json`); II:
the new key is optional, namespaced and ignored by the CLI, and existing keys keep their meaning; III–VI unchanged;
VII: docs, schema descriptions and TSDoc change with the code, and the live test checks two projects.
