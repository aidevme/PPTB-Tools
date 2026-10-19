# Contract: custom `enum.ejs` and the dataverse-gen CLI

<!-- cspell:ignore statuscode -->

The custom template is an interface to another program: the dataverse-gen CLI reads `<templateRoot>/enum.ejs` from the
project when it exists (2.0.17, `lib/TemplateProvider.js`) and renders it with EJS.

## Input (provided by the CLI)

EJS data for one enum, available as top-level names and as `locals.*`:

| Name | Type | Meaning |
| --- | --- | --- |
| `Name` | string | The enum's name, for example `account_statuscode` |
| `Members` | `{ Name: string; Value: string }[]` | Members in option order; `Name` is already made code-safe |
| `StringMembers` | boolean (optional) | `true` for `$metadata` enum types: the value is the member name in quotes |

## Output

Identical to dataverse-gen 2.0.17's `enum.ejs`, byte for byte (header comment, `export const enum`, two-space indent,
closing `}` followed by a newline and two spaces), except that every member name is passed through the renaming rule:

- keep a set of used names, in member order;
- while the member's name is in the set, append `_` and the member's `Value`;
- add the final name to the set and print it.

For string-valued enums the value printed is the final name, as dataverse-gen and the tool both do (no duplicates can
occur there; research R1).

## Guarantees checked by tests

1. For every test enum model, `ejs.render(customEnum, model)` equals the tool's
   `renderEnum(renameDuplicateEnumMembers(model))`.
2. For a model without duplicates, `ejs.render(customEnum, model)` equals `ejs.render(dataverseGenEnum, model)`: the
   custom template changes nothing unless there's a duplicate.
3. Control: `ejs.render(dataverseGenEnum, model)` equals the tool's `renderEnum(model)`, so the comparison in (1) is
   against the same baseline the CLI uses.
