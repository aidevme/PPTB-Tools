---

description: "Task list for the custom enum template for duplicate identifiers"
---

# Tasks: Custom enum template for duplicate identifiers

**Input**: Design documents from `specs/001-duplicate-identifier-templates/` (plan, spec, research, data model,
contracts, quickstart)

**Prerequisites**: plan.md and spec.md, both approved on 2026-10-19. This task list was approved on 2026-10-19.

**Tests**: included. Constitution Principle V requires a test for every task with logic, named in the task.

**Organization**: tasks are grouped by user story. Paths are relative to
`tools/dataverse-early-bound-typescript-generator/` unless they start at the repository root (`/`).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story the task belongs to (US1, US2, US3)

**After every task** (constitution, Development Workflow): `npm run build` and `npm test` pass, `npm run lint:tsdoc`
reports no new warning, changed Markdown passes `Validate-Markdown.ps1`, and the task is committed on its own through
`aidevme-github` with its task ID in the message.

---

## Phase 1: Setup

**Purpose**: the test-only dependency and file protection the later tasks rely on

- [x] T001 Add `ejs@3.1.10` as a devDependency (`npm install --save-dev ejs@3.1.10`) in `package.json` and
  `package-lock.json`; confirm it isn't imported from `src/` and that `npm audit` reports no new high or critical
  finding (research R3, decision D1)
- [x] T002 [P] Add `tools/dataverse-early-bound-typescript-generator/src/assets/custom-templates/*.ejs -text` to the
  repository's `/.gitattributes`, next to the existing rule for `dataverse-gen-templates` (research R4)

---

## Phase 2: Foundational (blocks all user stories)

**Purpose**: the setting, the custom template and its proof, and template selection

- [x] T003 Add the tool setting `customEnumTemplate` (boolean, default `false`; "Non-boolean or missing values fall
  back to the default") to `ToolConfig`, the defaults and `mergeToolConfig` in `src/config/index.ts`, and to
  `src/config/dataverse-early-bound-typescript-generator-config.json`, `…-config.schema.json` (description, type,
  default) and `…-config.sample.json`; tests in `test/settings.test.ts` (tool config: default, merge, invalid value)
- [x] T004 Create `src/assets/custom-templates/enum.ejs`: dataverse-gen 2.0.17's `enum.ejs` with the renaming loop
  from `contracts/custom-enum-template.md` (used-name set in member order; append `_<Value>` while taken), keeping
  the header, indentation and the closing `}` + newline + two spaces
- [x] T005 Add `test/customEnumTemplate.test.ts` rendering with `ejs` the three guarantees of
  `contracts/custom-enum-template.md` (custom template = `renderEnum(renameDuplicateEnumMembers(model))`; custom =
  original when there are no duplicates; control: original = `renderEnum(model)`) over models with no duplicates, one
  duplicate, a taken renamed name (`Open`, `Open`, `Open_3`), and a string-valued enum
- [x] T006 Extend `dataverseGenTemplateFiles(config, options)` in `src/services/dataverseGenTemplates.ts` with
  `{ customEnum?: boolean }`, importing `../assets/custom-templates/enum.ejs?raw`, so `enum.ejs` gets the custom
  content and the other six stay dataverse-gen's; tests in `test/dataverseGenTemplates.test.ts` (default output
  byte for byte unchanged; with `customEnum` only `enum.ejs` differs)
- [x] T007 [P] Correct the TSDoc of `renameDuplicateEnumMembers` in `src/core/generator.ts`: string-valued enums come
  from `$metadata` enum types, whose member names are unique, so they have no duplicates to rename (research R1)

**Checkpoint**: the custom template exists and is proven to match the tool; nothing in the UI changes yet.

---

## Phase 3: User Story 1 - Get a proposal when a preview finds duplicate identifiers (Priority: P1) 🎯 MVP

**Goal**: with duplicates, the Preview card proposes the custom enum template; accepting it renames duplicates in the
output and writes the custom `enum.ejs` on the next Generate, after a preview that lists it.

**Independent Test**: preview a project with two labels that become the same name, accept the proposal, preview and
generate; the files compile and `_templates/enum.ejs` is the custom template.

- [x] T008 [US1] In `src/hooks/usePreviewGenerate.ts`, rename when `renameDuplicateIdentifiers` or
  `customEnumTemplate` is on, and pass `{ customEnum: generateTemplates && customEnumTemplate }` to
  `dataverseGenTemplateFiles`; add `customEnumTemplate` to the preview's dependencies; tests in `test/hooks.test.ts`
  (with the setting on: no `duplicate` files, `_templates/enum.ejs` is `changed`; with Generate templates off:
  renamed output, no template files)
- [ ] T009 [US1] Add `'customEnumTemplate'` to `PreviewSettingKey` in `src/hooks/useToolSettings.ts` and mark the plan
  stale when it changes; add it to the defaults in `src/hooks/useSettingsDraft.ts`; tests in `test/hooks.test.ts`
  (changing it saves the setting and marks the plan stale)
- [ ] T010 [P] [US1] Add `CUSTOM_ENUM_TEMPLATE_TITLE` ("Custom enum template") and `CUSTOM_ENUM_TEMPLATE_INFO` to
  `src/components/shared/settingsInfo.tsx`, per `contracts/preview-proposal.md` (what it renames, that it replaces the
  project's `enum.ejs`, that it needs a new preview, that the CLI only gets it while Generate templates is on, and that
  renaming the labels in Dataverse is the lasting fix)
- [ ] T011 [US1] Add the proposal to the Preview card (`src/components/cards/PreviewCard.tsx`,
  `src/components/cards/PreviewParts.tsx`, and `src/styles/PreviewCard.styles.ts` if spacing is needed): new props
  `customEnumTemplate`, `generateTemplates` and `onCustomEnumTemplateChange`; a warning `MessageBar` with a title, the
  number of files with duplicate identifiers and the explanation, **Use custom enum template** and **Not now**; shown
  only when the plan has `duplicate` files and the setting is off; **Not now** hides it until the next preview
  (reset when `previewedAt` changes); the Generate-templates-off sentence; tests in `test/duplicateIdentifiers.test.ts`
  (shown with duplicates, also when Skip duplicated identifier(s) is on; hidden without; accept calls the handler with
  `true`; Not now hides it and calls nothing; shown again after a new preview; the templates-off sentence)
- [ ] T012 [US1] Pass `customEnumTemplate`, `generateTemplates` and
  `onCustomEnumTemplateChange: (checked) => changeSetting('customEnumTemplate', checked)` to the Preview card in
  `src/components/apps/App.tsx`

**Checkpoint**: User Story 1 works end to end in the unit tests.

---

## Phase 4: User Story 2 - Decline the proposal (Priority: P2)

**Goal**: declining keeps dataverse-gen's default output and templates, and the existing duplicate handling.

**Independent Test**: with duplicates, choose **Not now** and generate; the output equals today's default output.

- [ ] T013 [US2] Tests in `test/duplicateIdentifiers.test.ts` and `test/hooks.test.ts`: after **Not now**, the
  setting stays off, the files keep the `duplicate` status, the default `enum.ejs` is planned, and the Rename and Skip
  duplicated identifier(s) switches behave as before (no production change expected; fix any gap the tests show)

---

## Phase 5: User Story 3 - Go back to the default templates (Priority: P3)

**Goal**: the custom enum template can be turned on and off in the settings, and off restores the defaults.

**Independent Test**: turn the setting off, preview: `enum.ejs` and the enum files are planned as dataverse-gen's again.

- [ ] T014 [US3] Add the **Custom enum template** switch to the Duplicate identifiers card (Generate & files tab) in
  `src/components/panels/SettingsPanel.tsx` and to the Preview card's action bar in
  `src/components/cards/PreviewParts.tsx`, both with `CUSTOM_ENUM_TEMPLATE_INFO`; while it's on, show the Rename
  duplicated identifier(s) switch as on and disabled with "on because Custom enum template is on"; tests in
  `test/settings.test.ts` (switch saves `customEnumTemplate`; Rename disabled while on) and
  `test/duplicateIdentifiers.test.ts` (Preview card switch), and in `test/hooks.test.ts` (off again: default
  `enum.ejs` and default member names planned)

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T015 [P] Update `README.md`: "What this tool changes" (the custom template replaces the project's `enum.ejs`
  when on), "Deliberate deviations from dataverse-gen output" (custom enum template, opt-in) and Credits; and
  `THIRD_PARTY_NOTICES.md` (the modified `enum.ejs` derives from dataverse-gen, MIT)
- [ ] T016 [P] Update the docs in `/docs/pptb-tools/dataverse-early-bound-typescript-generator/`:
  `guide/tool-settings.md`, `guide/troubleshooting.md` (duplicate identifiers), `guide/what-gets-generated.md`
  (templates), `components/cards/preview-card.md` and `components/panels/settings-panel.md`
- [ ] T017 Check the TSDoc of every changed export (`aidevme-tsdoc`), run `npm run lint:tsdoc`, then `npm run docs:api`
  from the repository root and commit the regenerated API pages
- [ ] T018 Full verification from the tool folder: `npm run build`, `npm test`, `npm run validate` (the manifest
  changed through T001) and `npm audit`; record the results for the pull request
- [ ] T019 Live test in PPTB per `quickstart.md` (a person: light and dark themes, keyboard, Generate templates off,
  optional CLI parity) and record it with the date and PPTB version in
  `/docs/pptb-tools/dataverse-early-bound-typescript-generator/contributing/testing.md` and `TESTING.md`
- [ ] T020 Run `/speckit-converge` and repeat implement/converge until it reports Converged

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (T001–T002)**: no dependencies.
- **Foundational (T003–T007)**: after Setup. T005 needs T001 and T004; T006 needs T004. Blocks all user stories.
- **US1 (T008–T012)**: after Foundational. T008 needs T003 and T006; T009 needs T003; T011 needs T010; T012 needs
  T009 and T011.
- **US2 (T013)**: after US1 (it tests the proposal's **Not now**).
- **US3 (T014)**: after US1 (it shares `settingsInfo` and the Preview card).
- **Polish (T015–T020)**: after the user stories; T019 needs a person and a Dataverse environment.

### Parallel Opportunities

- T002 with T001; T007 with T003–T006; T010 with T008–T009; T015 with T016.
- In practice the tasks run one at a time, each committed separately.

---

## Implementation Strategy

### MVP First (User Story 1)

1. Setup and Foundational (T001–T007).
2. User Story 1 (T008–T012). **Stop and validate** with the unit tests and, if possible, a quick live preview.
3. Then US2 (T013) and US3 (T014), then Polish (T015–T020).

---

## Notes

- One commit per task, in Conventional Commits format, for example
  `feat(dataverse-early-bound-typescript-generator): add the customEnumTemplate setting (T003)`.
- No task changes `test/reference/`, `test/fixtures/` or `src/assets/dataverse-gen-templates/`; if one would, stop and
  ask (constitution II and V).
- The feature isn't done before T019 (live test) and T020 (Converged).
