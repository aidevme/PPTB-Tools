# Contract: the proposal and the setting in the UI

## Proposal (Preview card)

- **Shown when:** a preview has finished, the plan has at least one file with duplicate identifiers, the custom enum
  template is off, and the proposal hasn't been dismissed for this preview.
- **Content:** a warning message bar saying how many files have duplicate identifiers and won't compile, what the
  custom enum template does (later duplicates become `<Name>_<Value>` in the generated files, and the project's
  `enum.ejs` is replaced so the dataverse-gen CLI does the same), that nothing changes until the next preview and
  Generate, and that renaming the labels in Dataverse is the lasting fix. With Generate templates off it adds that
  the CLI won't get the fix while templates aren't written.
- **Actions:** **Use custom enum template** (saves the setting on, marks the preview stale) and **Not now** (hides the
  proposal until the next preview; nothing is saved).
- **Accessibility:** the message bar has a title and both actions are buttons reachable by keyboard; the text doesn't
  rely on color; it reads in light and dark themes (Fluent intent colors).

## Setting

- **Label:** "Custom enum template", with the same explanation (an `InfoLabel`) in both places, from
  `components/shared/settingsInfo.tsx`.
- **Where:** the Settings panel's Generate & files tab, in the Duplicate identifiers card; and the Preview card's
  action bar next to Rename and Skip duplicated identifier(s).
- **Behavior:** changing it saves `customEnumTemplate` and marks the preview stale (like `renameDuplicateIdentifiers`).
  While it's on, the Rename switch shows as on and disabled, with "on because Custom enum template is on" in its
  explanation, since the custom template implies renaming.
