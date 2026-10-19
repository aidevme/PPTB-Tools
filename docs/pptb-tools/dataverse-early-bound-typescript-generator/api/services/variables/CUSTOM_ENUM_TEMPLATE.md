# Variable: CUSTOM\_ENUM\_TEMPLATE

> `const` **CUSTOM\_ENUM\_TEMPLATE**: `string` = `customEnumTemplate`

Defined in: [services/dataverseGenTemplates.ts:39](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/services/dataverseGenTemplates.ts#L39)

The custom `enum.ejs`: dataverse-gen's, plus renaming of later duplicate members to `<Name>_<Value>`, the rule
`renameDuplicateEnumMembers` applies, so the dataverse-gen CLI writes the same names as the tool (spec 001).
