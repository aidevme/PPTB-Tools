# Function: renameDuplicateEnumMembers()

> **renameDuplicateEnumMembers**(`enumModel`): [`EnumModel`](../interfaces/EnumModel.md)

Defined in: [core/generator.ts:48](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/generator.ts#L48)

The enum with every later duplicate member renamed to `<Name>_<Value>` (for example `InProgress_700970000`), so the
file compiles. The first member with a name keeps it. A renamed name that's itself taken gets the value appended
again until it's free. Members are kept in order with their values.

## Parameters

### enumModel

[`EnumModel`](../interfaces/EnumModel.md)

The enum as built from the metadata.

## Returns

[`EnumModel`](../interfaces/EnumModel.md)

A copy with unique member names; members that didn't need renaming are the same objects.

## Remarks

Only choice (option set) enums can have duplicates: their member names come from labels made code-safe.
`StringMembers` enums come from the `$metadata` enum types, whose member names are unique, so they're returned with
the same names. (A renamed string member would also change its value, since the value is the member name.) The
custom `enum.ejs` (`CUSTOM_ENUM_TEMPLATE`) applies the same rule for the dataverse-gen CLI.
