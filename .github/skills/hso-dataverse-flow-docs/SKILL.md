---
name: hso-dataverse-flow-docs
layer: atomic
scope: core
description: |
  Generate and maintain detailed markdown documentation for Power Automate cloud flows
  from unpacked Dataverse solution Workflows folders. Outputs per-flow docs and a README index
  to Solutions/.docs/[SolutionName]/Workflows/. Use when:
  (1) User asks to "generate flow docs", "document flows", or "update flow documentation"
  (2) User asks to "generate workflow docs for [solution]" or "document the flows in [solution]"
  (3) After a solution export that includes Workflow changes
  (4) User wants to regenerate or refresh flow documentation for any solution
  (5) User asks what flows exist in a solution or wants a flow inventory
---

# Power Automate Flow Documentation Generator

Generate comprehensive markdown documentation for Power Automate cloud flows stored in unpacked Dataverse solutions.

## Prerequisites

The solution must be unpacked with a `Workflows/` folder containing:
- `FlowName-GUID.json` - flow definition files
- `FlowName-GUID.json.data.xml` - companion metadata files

## Workflow

### 1. Determine the solution name

If the user specifies a solution, use it. Otherwise, discover solutions that have Workflows:

```powershell
Get-ChildItem -Path "Solutions" -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName "Workflows")
} | Select-Object -ExpandProperty Name
```

If multiple solutions have Workflows, ask the user which to document (or document all).

### 2. Run the documentation generator

Execute the script from the **repository root**:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-flow-docs/scripts/Generate-FlowDocs.ps1" -SolutionsRoot "Solutions" -SolutionName "<SOLUTION_NAME>"
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-SolutionsRoot` | Yes | Path to the Solutions folder (usually `"Solutions"`) |
| `-SolutionName` | Yes | Solution unique name (e.g., `HSOSalesAutomation`) |
| `-OutputRoot` | No | Override output base path (defaults to `Solutions/.docs`) |
| `-FlowName` | No | Partial name match to document a single flow |

**Single flow example:**
```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-flow-docs/scripts/Generate-FlowDocs.ps1" -SolutionsRoot "Solutions" -SolutionName "HSOSalesAutomation" -FlowName "AccountCreate"
```

### 3. Review output

The script produces:
- Individual `.md` files per flow in `Solutions/.docs/[SolutionName]/Workflows/`
- A `README.md` index listing all flows with state and trigger type

### 4. Report results

After generation, summarize to the user:
- Number of flows documented
- Any errors encountered
- Output location

## Output Format

See [flow-documentation-format.md](references/flow-documentation-format.md) for the full output specification.

## Directory Structure

```
Solutions/.docs/[SolutionName]/Workflows/
├── README.md              (auto-generated index)
├── FlowName-One.md        (per-flow documentation)
├── FlowName-Two.md
└── ...
```
