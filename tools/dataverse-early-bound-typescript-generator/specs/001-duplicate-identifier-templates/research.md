# Research: Custom enum template for duplicate identifiers

<!-- cspell:ignore sval -->

Feature: [spec.md](./spec.md) · Plan: [plan.md](./plan.md) · Date: 2026-10-19

## R1. How duplicates arise and which enums can have them

- **Decision:** only choice (option set) enums can have duplicate members; enums from the CSDL's enum types can't.
- **Rationale:** dataverse-gen 2.0.17 (`lib/SchemaModel.js`, `addEnum`) builds a choice member's name with
  `makeCodeSafe(label)`, which strips every non-word character, so "In Progress" and "In-Progress" both become
  `InProgress`; the tool's port (`core/model.ts`) does the same. Enum types from `$metadata` (`StringMembers: true` in
  `buildSchemaModel`) keep their CSDL member names, which OData CSDL requires to be unique within the enum type.
- **Consequence:** the spec's "string-valued members keep their original value" (FR-005, edge cases) can't be
  exercised: no string-valued enum has a duplicate to rename. The custom template still handles string enums exactly
  like the tool does (it prints the member name as the value), so the two stay identical. The TSDoc of
  `renameDuplicateEnumMembers` says string enums "keep their string values", which isn't what rendering does; a task
  corrects that comment.
- **Alternatives considered:** carrying the original name for string members (both in the tool and the template) —
  rejected as dead code for a case CSDL rules out.

## R2. Does the tool render with the template it writes?

- **Decision:** no. The tool keeps rendering with `core/templates.ts` and renames with `renameDuplicateEnumMembers`; the
  custom `enum.ejs` is written for the dataverse-gen CLI only.
- **Rationale:** EJS compiles templates with `new Function`, which PPTB's tool CSP (`script-src 'self'
  'unsafe-inline'`, no `'unsafe-eval'`) blocks; `cspExceptions` documents no way to allow it (constitution III).
  Renaming in the tool's own pipeline already exists and is tested.
- **Alternatives considered:** an in-sandbox interpreter (sval) running the project's templates — out of scope (spec
  Assumptions); requesting `'unsafe-eval'` — undocumented and weakens the sandbox.

## R3. Proving the CLI and the tool produce the same names (SC-003, FR-007)

- **Decision:** a vitest test renders the custom `enum.ejs` with the real `ejs` package and compares it with the tool's
  `renderEnum(renameDuplicateEnumMembers(model))` for a set of enum models (no duplicates, one duplicate, a chain where
  the renamed name is taken, string-valued). A control test renders dataverse-gen's own `enum.ejs` the same way and
  compares it with `renderEnum(model)`.
- **Rationale:** it's the only check that runs the template the way the CLI does. `ejs` is added as a
  **devDependency** (`ejs@3.1.10`, Apache-2.0; dataverse-gen 2.0.17 declares `ejs ^3.1.5`, so the CLI can resolve to
  the same version); it's only imported by the test,
  so it never reaches the IIFE bundle and never runs in PPTB.
- **Data shape:** dataverse-gen passes the enum model as EJS data (`Name`, `Members[{ Name, Value }]`,
  `StringMembers`) and uses `locals.*` in the template, which the test reproduces with
  `ejs.render(template, enumModel)`.
- **Alternatives considered:** a hand-written port of the custom template's loop in TypeScript — rejected: it would
  test the port, not the template. Running the dataverse-gen CLI in tests — rejected: needs its install and a
  Dataverse connection.

## R4. Where the custom template lives

- **Decision:** `src/assets/custom-templates/enum.ejs`, a new file next to the protected
  `src/assets/dataverse-gen-templates/`, which stays byte for byte dataverse-gen 2.0.17's.
- **Rationale:** constitution II keeps the original templates untouched. The custom file is derived from
  dataverse-gen's `enum.ejs` (MIT), so `THIRD_PARTY_NOTICES.md` and the README credits mention the modification.
- **Line endings:** the new file gets the same `.gitattributes` protection as the originals, so the bytes written to
  projects don't depend on the checkout's line-ending settings.

## R5. Setting model

- **Decision:** a new tool setting `customEnumTemplate` (boolean, default `false`). The tool renames duplicates when
  `renameDuplicateIdentifiers || customEnumTemplate`; Generate writes the custom `enum.ejs` when
  `customEnumTemplate && generateTemplates`.
- **Rationale:** spec FR-009/FR-010 make it one tool-wide setting. Deriving the rename from either key means turning
  the custom template off restores the default output (US3) without touching `renameDuplicateIdentifiers`, which keeps
  its own meaning (rename in the tool only, no template).
- **Alternatives considered:** accepting the proposal sets `renameDuplicateIdentifiers` too — rejected: turning the
  custom template off later would leave renaming on, against US3.

## R6. Proposal placement and lifetime

- **Decision:** a warning `MessageBar` in the Preview card, shown when the current plan has `duplicate` files and
  `customEnumTemplate` is off, with **Use custom enum template** and **Not now**. **Not now** hides it until the next
  preview (component state reset per preview); nothing is stored (spec Q1).
- **Rationale:** the duplicates are reported there; the existing Rename and Skip switches live there too.
- **Generate templates off:** the proposal still offers the setting and adds that the CLI won't get the fix until
  Generate templates is on.
