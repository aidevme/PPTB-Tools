# Feature Specification: Custom enum template for duplicate identifiers

**Feature Branch**: `features/dataverse-early-bound-typescript-generator` (existing branch; no new branch)

**Created**: 2026-10-19

**Status**: Approved (2026-10-19)

**Input**: User description: "By default use the default templates; if any duplicates are found, propose to the user to use
custom templates." Agreed meaning of "custom templates": the tool writes a fixed `enum.ejs` to the project's templates
folder, which gives duplicate choice members unique names for the dataverse-gen CLI, and turns on renaming for its own
output, so both produce the same names.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Get a proposal when a preview finds duplicate identifiers (Priority: P1)

A developer previews a project whose choices have labels that turn into the same member name (for example "In
Progress" and "In-Progress"). Today the preview flags the affected files, and they won't compile. With this feature the
preview also proposes a fix: use a custom enum template that gives every duplicate a unique name. The developer accepts
it, previews again, and sees that the duplicates are resolved and which files will change. After Generate, the
generated enum files compile, and the project's templates folder holds the custom enum template, so the dataverse-gen
CLI produces the same names.

**Why this priority**: duplicate identifiers break the build of every project that uses the generated types. Today
the only fixes are renaming labels in Dataverse or finding the Rename setting; the proposal brings the fix to where
the problem is reported.

**Independent Test**: open a project whose metadata has two choice labels that produce the same name, preview, accept
the proposal, preview and generate, then compile the generated files and run the dataverse-gen CLI on the project.

**Acceptance Scenarios**:

1. **Given** default settings and a preview with at least one duplicate identifier, **When** the preview finishes,
   **Then** the preview shows a proposal that names how many files have duplicates and explains what accepting does.
2. **Given** a preview with no duplicate identifiers, **When** the preview finishes, **Then** no proposal is shown and
   the output uses the default templates, unchanged.
3. **Given** the proposal is shown, **When** the developer accepts it, **Then** nothing is written to disk yet, the
   preview becomes stale, and the next preview lists the affected enum files and the project's `enum.ejs` as changed.
4. **Given** the proposal was accepted, **When** the developer generates, **Then** later duplicate members are written
   as `<Name>_<Value>` (the first keeps its name), and the project's templates folder has the custom `enum.ejs`.
5. **Given** the custom `enum.ejs` in the project, **When** the dataverse-gen CLI generates the same selection, **Then**
   its enum files have the same member names as the tool's.

---

### User Story 2 - Decline the proposal (Priority: P2)

A developer who prefers to fix the labels in Dataverse, or to skip the affected files, declines the proposal and keeps
the default templates.

**Why this priority**: the default output must stay exactly dataverse-gen's unless the developer chooses otherwise.

**Independent Test**: with duplicates present, decline the proposal and generate; the output is identical to today's
default output.

**Acceptance Scenarios**:

1. **Given** the proposal is shown, **When** the developer declines it, **Then** the output and the project's
   templates stay the defaults, and the existing duplicate warnings and the Skip duplicated identifier(s) switch work
   as today.
2. **Given** the developer declined, **When** a later preview of the same project finds duplicates again, **Then**
   the proposal is shown again: declining only hides it for that preview, and nothing is stored.

---

### User Story 3 - Go back to the default templates (Priority: P3)

A developer who accepted the proposal fixes the labels in Dataverse later and wants dataverse-gen's default output and
templates again.

**Why this priority**: the choice must be reversible without editing files by hand.

**Independent Test**: after accepting, turn the custom enum template off, preview and generate; the output and the
project's `enum.ejs` are dataverse-gen's defaults again.

**Acceptance Scenarios**:

1. **Given** the custom enum template is in use, **When** the developer turns it off in the settings, **Then** the next
   preview lists the project's `enum.ejs` as changed back to the default, and Generate writes the default template and
   default member names.

---

### Edge Cases

- **Generate templates is off**: the tool doesn't write templates at all. Accepting the proposal still renames
  duplicates in the tool's output, and the proposal and the setting say that the CLI won't get the fix while
  templates aren't written.
- **The project already has an edited `enum.ejs`**: writing the custom template replaces it, as Generate does with any
  template today; the preview lists it as changed before anything is written.
- **A renamed name is itself taken** (for example `InProgress_1` already exists): the value is appended again until the
  name is free, in the tool and in the custom template alike.
- **String-valued enums**: renamed members keep their original string value, so values at run time don't change.
- **Option order changes in Dataverse**: which member keeps the plain name follows the option order, so a reorder can
  move the suffix to another member; the proposal and the docs say so.
- **Skip duplicated identifier(s) is on**: the proposal is still shown; accepting it makes skipping unnecessary, and the
  files with duplicates are written with renamed members.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: By default the tool MUST generate with the default templates, and its output MUST stay identical to
  dataverse-gen's (apart from the deviations already listed in the README).
- **FR-002**: When a preview finds at least one file with duplicate identifiers and the custom enum template isn't in
  use, the preview MUST show a proposal to use it, with the number of affected files and what accepting changes.
- **FR-003**: The proposal MUST NOT be shown when the preview finds no duplicate identifiers.
- **FR-004**: Accepting the proposal MUST NOT write any file. It changes the setting, marks the preview stale, and the
  files change only on the next Generate, after a preview that lists them.
- **FR-005**: With the custom enum template in use, the generated enum files MUST give every later duplicate member the
  name `<Name>_<Value>` (appending the value again while the name is taken); the first member with a name keeps it, and
  string-valued members keep their original value.
- **FR-006**: With the custom enum template in use and Generate templates on, Generate MUST write the custom `enum.ejs`
  to the project's templates folder instead of dataverse-gen's, and MUST write dataverse-gen's other six templates
  unchanged.
- **FR-007**: The custom `enum.ejs`, run by the dataverse-gen CLI, MUST produce the same member names as the tool for
  the same metadata.
- **FR-008**: Developers MUST be able to decline the proposal; declining MUST leave the output and templates at their
  defaults.
- **FR-009**: Developers MUST be able to turn the custom enum template on and off in the settings, without a
  duplicate being present, and turning it off MUST restore the default output and templates on the next Generate.
- **FR-010**: The choice MUST be a tool setting that applies to every project, like Rename duplicated identifier(s)
  today: shown in the Settings panel and on the Preview card, and saved with the tool's settings. Declining the
  proposal MUST NOT be stored.
- **FR-011**: The README's "What this tool changes" and "Deliberate deviations from dataverse-gen output" sections, the
  user guide and the Settings panel explanations MUST describe the custom enum template, including that it overwrites
  an existing `enum.ejs`.

### Key Entities

- **Custom enum template**: a variant of dataverse-gen's `enum.ejs` that gives duplicate members unique names; written
  to the project's templates folder in place of the default one when in use.
- **Duplicate identifier**: two or more members of one generated enum whose names are equal after the label is turned
  into an identifier; already detected and reported per file today.
- **Custom enum template setting**: whether the custom template is in use; turning it on also renames duplicates in the
  tool's own output.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a project with duplicate identifiers, a developer goes from seeing the problem to generated files that
  compile in at most three actions: accept the proposal, preview, generate.
- **SC-002**: For a project without duplicate identifiers, the generated output and templates are byte for byte the
  same as before the feature.
- **SC-003**: For the same metadata and selection, the enum member names written by the tool and by the dataverse-gen
  CLI with the custom template are identical in 100% of the enum files.
- **SC-004**: Accepting or turning off the custom template never changes a file before a preview has listed the change.

## Assumptions

- "Custom templates" means only the enum template; the other six templates stay dataverse-gen's. Rendering arbitrary
  edited templates is out of scope (it would need a template engine that runs inside PPTB).
- The tool keeps generating with its built-in renderer; it doesn't read the project's `.ejs` files. The custom
  template exists so the dataverse-gen CLI produces the same names.
- The renaming rule is the existing Rename duplicated identifier(s) rule (`<Name>_<Value>`, first member keeps its
  name), so accepting the proposal is equivalent to that setting plus the custom template.
- Fixing the labels in Dataverse remains the recommended long-term fix, and the proposal says so.
- Clarified on 2026-10-19: the proposal is shown on every preview with duplicates until accepted (Q1), and the choice
  is a tool setting for every project (Q2).
- Out of scope: changing labels in Dataverse, other kinds of duplicates (for example two tables with the same name), and
  writing templates when a project is created.
