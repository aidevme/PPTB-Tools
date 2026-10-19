# Data model: Custom enum template for duplicate identifiers

Feature: [spec.md](./spec.md) · Plan: [plan.md](./plan.md)

## Tool setting `customEnumTemplate`

| Field | Type | Default | Stored in | Validation |
| --- | --- | --- | --- | --- |
| `customEnumTemplate` | boolean | `false` | The tool's PPTB settings (`toolConfig`), like `renameDuplicateIdentifiers` | Non-boolean or missing values fall back to the default (`mergeToolConfig`) |

Also declared in `src/config/dataverse-early-bound-typescript-generator-config.json` (default),
`…-config.schema.json` (description, type, default) and `…-config.sample.json`. It isn't written to
`.dataverse-gen.json`, so the dataverse-gen CLI's project file is unchanged (constitution II).

### Derived values

| Value | Rule | Used by |
| --- | --- | --- |
| Rename duplicates in the tool's output | `renameDuplicateIdentifiers` or `customEnumTemplate` is on | `generate(…, { renameDuplicateIdentifiers })` in `usePreviewGenerate` |
| Write the custom `enum.ejs` | `generateTemplates` and `customEnumTemplate` are both on | `dataverseGenTemplateFiles(config, { customEnum })` |
| Show the proposal | the current plan has `counts.duplicate > 0`, `customEnumTemplate` is off, and it wasn't dismissed for this preview | Preview card |

### State transitions

```text
off ──(accept proposal, or switch on)──▶ on      : plan becomes stale; next preview renames and lists enum.ejs as changed
on  ──(switch off)─────────────────────▶ off     : plan becomes stale; next preview restores default names and enum.ejs
proposal shown ──(Not now)──▶ hidden until the next preview (not stored)
```

## Template file `_templates/enum.ejs`

| Setting state | Content written |
| --- | --- |
| `generateTemplates` off | nothing (unchanged behavior) |
| `generateTemplates` on, `customEnumTemplate` off | dataverse-gen 2.0.17's `enum.ejs`, byte for byte (unchanged behavior) |
| `generateTemplates` on, `customEnumTemplate` on | the custom `enum.ejs` from `src/assets/custom-templates/` |

The other six templates are always dataverse-gen's. The file goes through the write plan like every template, so it's
`new`, `changed` or `unchanged` in the preview before Generate writes it (constitution I).

## Enum member renaming (unchanged rule)

For each enum, in member order: a name already used by an earlier member gets `_<Value>` appended, repeatedly until
it's unused; the first member with a name keeps it. String-valued enums (from `$metadata` enum types) can't contain
duplicates (see research R1).

## Amendment 2: per project

| Field | Type | Default | Stored in |
| --- | --- | --- | --- |
| `pptbEarlyBoundGenerator.customEnumTemplate` | boolean (optional) | from `projectDefaults.customEnumTemplate` when missing | The project's `.dataverse-gen.json`, saved by Generate |
| `projectDefaults.customEnumTemplate` | boolean | `false` | The tool's PPTB settings (Settings → Generate & files); replaces the top-level `customEnumTemplate` above |

- Opening a project, or changing the default, fills in the project value only when the file has none.
- Rename duplicates in the output: `renameDuplicateIdentifiers` (tool) or the project's `customEnumTemplate`.
- Write the custom `enum.ejs`: `generateTemplates` (tool) and the project's `customEnumTemplate`.
