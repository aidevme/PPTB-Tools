# Live testing in Power Platform ToolBox

The unit tests (`npm test`) and the live checks in Power Platform ToolBox, with their results and the steps for
the remaining ones, are documented in the contributor guide:
[Testing](../../docs/pptb-tools/dataverse-early-bound-typescript-generator/contributing/testing.md).

**Status (2026-10-15, PPTB Desktop 1.2.7, tool 1.0.0):** connecting, listing tables, projects, selecting, the
Settings panel, Preview, Generate, deleting orphaned files (Windows) and the dark theme pass. Still to test: error
paths, following a theme switch while the tool is open, and orphan deletion on macOS and Linux.
