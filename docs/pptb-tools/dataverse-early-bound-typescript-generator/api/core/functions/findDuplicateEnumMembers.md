# Function: findDuplicateEnumMembers()

> **findDuplicateEnumMembers**(`enumModel`): [`DuplicateIdentifier`](../interfaces/DuplicateIdentifier.md)[]

Defined in: [core/generator.ts:25](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/core/generator.ts#L25)

Enum members that share a name. Option labels become member names after `makeCodeSafe`, so two labels
such as "Open" and "Open!" collide, and TypeScript rejects the file. The output is kept as dataverse-gen
writes it; the collision is only reported, so the labels can be fixed in Dataverse.

## Parameters

### enumModel

[`EnumModel`](../interfaces/EnumModel.md)

## Returns

[`DuplicateIdentifier`](../interfaces/DuplicateIdentifier.md)[]
