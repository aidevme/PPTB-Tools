# Type Alias: FileStatus

> **FileStatus** = `"new"` \| `"changed"` \| `"unchanged"` \| `"orphaned"` \| `"duplicate"`

Defined in: [types/WritePlan.ts:8](https://github.com/aidevme/PPTB-Tools/blob/a52eb34c296874a3eb2f07933e3e46daf95bb2f7/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L8)

Outcome of comparing generated files with what is on disk. `duplicate` marks a generated file that declares
a name more than once, so it won't compile; it takes the place of new, changed or unchanged, which is kept
in [PlannedFile.writeStatus](../interfaces/PlannedFile.md#writestatus).
