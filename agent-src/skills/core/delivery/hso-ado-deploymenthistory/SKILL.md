---
name: hso-ado-deploymenthistory
layer: atomic
scope: core
description: "Extract deployment history from Azure DevOps YAML pipelines and generate a Deployment_History.md document showing which solution versions were deployed to which environments and when. Use when: (1) User asks to 'update deployment history', 'refresh deployment history', or 'get deployment history' (2) User asks 'what version is deployed to QA/Training/Production?' (3) User asks to 'generate a deployment report' or 'show deployment timeline' (4) After a release pipeline completes and the user wants to update the deployment log. Uses a 3-pipeline structure (Export, Build, Release) and auto-discovers environments from pipeline stage names. Authentication is resolved automatically from settings, with PAT still available as an explicit override."
---

# ADO Deployment History

Extract deployment history from Azure DevOps and produce `agent\wiki\system\Deployment_History.md`.

> **"Release pipeline" below means the deploy YAML pipeline** — the one these templates
> commonly name `ReleaseSolutions` — not an Azure DevOps Release Management definition. The script reads run
> timelines and template parameters through the Pipelines/Build API. Classic releases live behind a
> different host (`vsrm.dev.azure.com`) and a different object model, so pointing this at one
> returns no runs rather than an error. A project deploying from the Releases hub needs a separate
> extraction against that API; this skill does not cover it.

## Prerequisites

- Azure DevOps access resolved automatically from settings, or a PAT with **Build (Read)** scope when you need an explicit override
- Configuration in CLAUDE.md/CLAUDE.local.md (org, project, pipeline names)

## Workflow

### 1. Collect Parameters

Get from user or CLAUDE.md/CLAUDE.local.md:

| Parameter | Source | Example |
|-----------|--------|---------|
| Org URL | CLAUDE.md or user | `https://dev.azure.com/MyOrg` |
| Project | CLAUDE.md or user | `My Project` |
| Export pipeline name | User or convention | `ExportSolutions` |
| Build pipeline name | User or convention | `BuildSolutions` |
| Release pipeline name | User or convention | `ReleaseSolutions` |
| Solution param map | User or pipeline inspection | See below |
| Solution XML paths | Auto-discovered from `Solutions/` folder | See below |

**Solution param map** links release pipeline template parameter names to solution folder names. The keys are the boolean template parameters in the release pipeline YAML that control which solutions get deployed; the values are the matching solution folder names in the repo.

Ask the user for this mapping, or inspect the release pipeline YAML if available. The number of entries varies per project.

```powershell
# Example — actual keys and values depend on the project's release pipeline
@{
    deploySolutionA = 'ProjectSolutionA'
    deploySolutionB = 'ProjectSolutionB'
}
```

**Solution XML paths** — auto-discover from the repo's `Solutions/` folder:

```powershell
# Discover all solutions in the repo
$solutionPaths = Get-ChildItem -Path "$RepoRoot/Solutions/*/Other/Solution.xml" -Recurse |
    ForEach-Object { $_.FullName -replace [regex]::Escape($RepoRoot + '\'), '' -replace '\\', '/' }
```

If the repo does not follow the `Solutions/<Name>/Other/Solution.xml` convention, ask the user for the paths.

### 2. Run the Extraction Script

Write a caller `.ps1` script that invokes `Get-DeploymentHistory.ps1` with the collected parameters.
The script path is relative to this skill: `scripts/Get-DeploymentHistory.ps1`.

```powershell
$skillScriptDir = '<absolute-path-to-this-skill>\scripts'
$outputJson = '<repo-root>\agent\wiki\system\deployment_data.json'

# Settings-resolved auth
& "$skillScriptDir\Get-DeploymentHistory.ps1" `
    -OrgUrl '<org-url>' `
    -Project '<project>' `
    -ExportPipeline '<export-pipeline-name>' `
    -BuildPipeline '<build-pipeline-name>' `
    -ReleasePipeline '<release-pipeline-name>' `
    -SolutionParamMap @{ <param>=<solution>; ... } `
    -SolutionXmlPaths @('<path1>', '<path2>', ...) `
    -RepoRoot '<repo-root>' `
    -OutputPath $outputJson `

# PAT auth (fallback)
& "$skillScriptDir\Get-DeploymentHistory.ps1" `
    -OrgUrl '<org-url>' `
    -Project '<project>' `
    -ExportPipeline '<export-pipeline-name>' `
    -BuildPipeline '<build-pipeline-name>' `
    -ReleasePipeline '<release-pipeline-name>' `
    -SolutionParamMap @{ <param>=<solution>; ... } `
    -SolutionXmlPaths @('<path1>', '<path2>', ...) `
    -RepoRoot '<repo-root>' `
    -OutputPath $outputJson `
    -Pat '<pat-token>'
```

Execute via: `powershell -ExecutionPolicy Bypass -File <caller-script>`

### 3. Generate the Markdown Document

Read the JSON output and generate `agent/wiki/system/Deployment_History.md` with these sections:

#### Current Environment State
For each environment, find the **latest successful** deployment and match it to the
closest preceding solution version. Show as a table:
`| Environment | Solution | Version | Deployed On | Build | Import Mode |`

#### Solution Version History
List all exported versions from `SolutionVersions` array:
`| Export Build | Version | Export Date |`

#### Successful Deployments (Chronological)
Filter `DeploymentRecords` where `Result = 'succeeded'`, grouped by month:
`| Date | Build | Environment | Solutions Deployed | Version | Import Mode |`

To map a deployment to a version: find the latest `SolutionVersions` entry whose date
is **on or before** the deployment's date.

#### Failed Deployments
Filter `DeploymentRecords` where `Result = 'failed'`:
`| Date | Build | Environment | Solutions | Failure Context |`

#### Reference Tables
- Environments table (auto-discovered from the data)
- Pipelines table (from the JSON `Pipelines` object)

### 4. Version Mapping Logic

The release pipeline deploys artifacts from the build pipeline, which packages the latest
export. To correlate a release build number to a solution version:

1. Find the release's date from `FinishTime`
2. Find the latest `SolutionVersions` entry with a `Date` on or before that date
3. That entry's `Version` is what was deployed

### 5. Cleanup

Delete the intermediate JSON file and any caller script after generating the markdown.

## Script Details

`scripts/Get-DeploymentHistory.ps1` handles:
- Authentication via shared ADO-Auth module (settings-resolved auth + PAT fallback)
- Project ID resolution (avoids URL encoding issues with project names containing spaces)
- Pipeline definition ID lookup by name
- Release run timeline parsing to auto-discover deployment stages
- Template parameter inspection for solution selection
- Git history parsing for solution version extraction

**Auto-discovery**: Environments are extracted from stage names matching `Deploy to <name>`.
No hardcoded environment list — new stages are picked up automatically.

**Solution detection**: Template parameters are checked against the provided `SolutionParamMap`.
Values of `'True'` or `'true'` indicate the solution was included in the deployment.

## Authentication

Uses the shared `ADO-Auth.ps1` module (same as `hso-ado-work-items`):
- **Interactive (preferred)**: MSAL.PS browser login with 3-tier caching (in-memory -> file -> browser)
- **PAT fallback**: For orgs that restrict OAuth consent, provide a PAT with Build (Read) scope
