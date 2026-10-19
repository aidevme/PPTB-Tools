# Function: renameDuplicateEnumMembers()

> **renameDuplicateEnumMembers**(`enumModel`): [`EnumModel`](../interfaces/EnumModel.md)

Defined in: [core/generator.ts:40](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/generator.ts#L40)

The enum with every later duplicate member renamed to `<Name>_<Value>` (for example `InProgress_700970000`), so the
file compiles. The first member with a name keeps it. A renamed name that's itself taken gets the value appended
again until it's free. Members are kept in order with their values; `StringMembers` enums keep their string values.

## Parameters

### enumModel

[`EnumModel`](../interfaces/EnumModel.md)

## Returns

[`EnumModel`](../interfaces/EnumModel.md)
