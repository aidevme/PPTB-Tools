# Type Alias: TableType

> **TableType** = `"Standard"` \| `"Activity"` \| `"Virtual"` \| `"Elastic"`

Defined in: [types/EntitySummary.ts:5](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/EntitySummary.ts#L5)

The kind of Dataverse table, as Power Apps shows it. Dataverse's `TableType` holds Standard, Virtual or Elastic;
activity tables report `Standard` there and are identified by `IsActivity` instead.
