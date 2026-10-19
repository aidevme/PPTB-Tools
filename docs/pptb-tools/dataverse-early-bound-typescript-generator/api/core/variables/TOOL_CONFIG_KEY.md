# Variable: TOOL\_CONFIG\_KEY

> `const` **TOOL\_CONFIG\_KEY**: `"pptbEarlyBoundGenerator"` = `'pptbEarlyBoundGenerator'`

Defined in: [core/config.ts:137](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/config.ts#L137)

Key of this tool's own settings object in `.dataverse-gen.json`. The dataverse-gen CLI keeps it (it writes the whole
file back) and ignores it; namespacing it means it can't collide with a future dataverse-gen option.
