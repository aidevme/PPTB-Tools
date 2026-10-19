# Moving from dataverse-gen

This tool is a TypeScript port of Scott Durow's [dataverse-gen](https://github.com/scottdurow/dataverse-gen)
2.0.17. If you already use the CLI, you can open your existing project and switch between the two.

## Shared project file

Both read and write the same [`.dataverse-gen.json`](./project-file.md). Open the project folder in the tool and
your selection and options load as they are. Generate saves the file again, and keys the tool doesn't know are
kept. After that, `npx dataverse-gen` works on the same folder.

## Same output

The generated files match the CLI's, character for character, so regenerating with either tool doesn't cause a
diff. Generated files use LF line endings, and the preview ignores CRLF versus LF, so a CRLF checkout shows as
unchanged.

### Deliberate differences

The output differs only where dataverse-gen emits code that doesn't compile:

- A property whose type is an entity outside the selection becomes `any` rather than the bare logical name.
- Form-context lines for attributes with no known Xrm type are skipped instead of emitting
  `Xrm.Attributes.undefinedAttribute`.
- Action and function parameters that are collections of enums or complex types get the right element type
  instead of `undefined[]`.
- An option label made only of symbols falls back to `_<value>` instead of an empty member name.
- With **Rename duplicated identifier(s)** on (off by default), a later enum member whose name repeats an earlier one
  gets its value appended (`InProgress_700970000`) instead of a second `InProgress` that doesn't compile.

If you switch back and forth, you may see these as one-time changes.

## What the tool adds

- **Private custom APIs:** listed and selectable even though `$metadata` doesn't include them. dataverse-gen can't
  generate these. See [What gets generated](./what-gets-generated.md).
- **Large `$metadata` fallback:** when the environment's `$metadata` is over PPTB's size limit, the tool builds
  tables and custom APIs from other metadata. See [Troubleshooting & limitations](./troubleshooting.md).
- **File-name casing:** if a file already exists with a name that differs only in casing, the tool reuses that
  name and rewrites the imports in `index.ts` and `metadata.ts` to match, as the CLI does.
- **No sign-in step:** the tool uses your PPTB connection, so dataverse-auth isn't involved.
- **A preview** that compares the result with your output folder before anything is written.

## What isn't implemented

- **Custom (ejected) EJS templates.** The tool writes dataverse-gen 2.0.17's templates to `templateRoot`
  (`_templates` by default) on every Generate, like `npx dataverse-gen eject`, so the CLI finds them there. It
  doesn't read them itself: EJS can't run in PPTB, whose iframe blocks `new Function`. Edits to them only affect
  the CLI, and the next Generate overwrites them with the originals. To keep edited templates, turn off **Settings
  → Generate & files → Generate templates**.
- **The Node CLI and the headless "regenerate" mode** from the original plan.
