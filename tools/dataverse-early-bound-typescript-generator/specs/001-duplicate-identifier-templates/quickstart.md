# Quickstart: validate the custom enum template

Feature: [spec.md](./spec.md) · Plan: [plan.md](./plan.md)

## Automated

From `tools/dataverse-early-bound-typescript-generator/`:

```powershell
npm install          # includes the ejs devDependency used only by the tests
npm run build        # typecheck + IIFE bundle
npm test             # includes the template equivalence and proposal tests
npm run lint:tsdoc
```

Expected: build OK, all tests pass (the template contract in [contracts/custom-enum-template.md](./contracts/custom-enum-template.md)
holds), no new TSDoc warnings. From the repository root, `npm run docs:api` regenerates the API pages.

## Live, in PPTB (constitution VII)

Prerequisites: a Dataverse environment with a choice that has two labels producing the same name (for example add a
choice column with options "In Progress" and "In-Progress"), and a project selecting that table.

1. **Default:** preview. The file is flagged with duplicate identifiers and the proposal appears. Nothing on disk
   changes.
2. **Not now:** the proposal disappears; preview again and it's back.
3. **Accept:** the preview is marked stale. Preview again: the enum file and `_templates/enum.ejs` are listed as
   changed and no file is flagged. Generate. The enum file has `InProgress` and `InProgress_<value>`; `tsc` on the
   project compiles.
   **Edited `enum.ejs` (Amendment 1):** turn the custom template off, edit `_templates/enum.ejs` in the project,
   preview, then turn the custom template on (from the proposal, the Preview card switch and the Settings panel): a
   dialog names the file and asks first; **Cancel** leaves it off.
4. **CLI parity (optional):** in the project, run the dataverse-gen CLI (where its sign-in works) on the same
   selection; its enum file has the same member names.
5. **Turn it off** in Settings → Generate & files; preview: the enum file and `enum.ejs` go back to the defaults.
6. **Generate templates off:** with the custom template on, the proposal/explanation says the CLI won't get the fix;
   `enum.ejs` isn't written.
7. Repeat 1–3 in the dark theme, and check keyboard access to both proposal buttons.

Record the result in `docs/pptb-tools/dataverse-early-bound-typescript-generator/contributing/testing.md` and
`TESTING.md` with the date and PPTB version.
