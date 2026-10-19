# Type Alias: FileStatus

> **FileStatus** = `"new"` \| `"changed"` \| `"unchanged"` \| `"orphaned"` \| `"duplicate"`

Defined in: [types/WritePlan.ts:8](https://github.com/aidevme/PPTB-Tools/blob/main/tools/dataverse-early-bound-typescript-generator/src/types/WritePlan.ts#L8)

Outcome of comparing generated files with what is on disk. `duplicate` marks a generated file that declares
a name more than once, so it won't compile; it takes the place of new, changed or unchanged, which is kept
in [PlannedFile.writeStatus](../interfaces/PlannedFile.md#writestatus).
