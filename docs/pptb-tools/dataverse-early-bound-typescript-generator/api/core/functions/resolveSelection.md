# Function: resolveSelection()

> **resolveSelection**(`edmx`, `config`): [`Selection`](../interfaces/Selection.md)

Defined in: [core/model.ts:55](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/core/model.ts#L55)

Work out which CSDL types the selection needs. Entities referenced by a selected action or function
(for example `opportunityclose` for `WinOpportunity`) are included even when not selected
themselves, exactly like dataverse-gen; complex types and enums are included transitively.

Callers use `selection.entities` to know which entities' metadata must be fetched before calling
[buildSchemaModel](buildSchemaModel.md).

## Parameters

### edmx

[`EdmxSchema`](../interfaces/EdmxSchema.md)

### config

[`ResolvedConfig`](../interfaces/ResolvedConfig.md)

## Returns

[`Selection`](../interfaces/Selection.md)
