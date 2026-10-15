---
name: hso-pipeline-generation
layer: orchestration
scope: core
description: |
  Generate the project's Azure DevOps YAML pipelines from declarative config blueprints rather than
  hand-maintaining N near-duplicate files. Reads pipeline-defaults.json + solution-organizer.json and
  stamps the pipeline set so project identity, environments, and solution layers stay coherent. Use
  when:
  (1) Initialising pipelines for a new project
  (2) Changing project identity, environments, or solution layers
  (3) Re-stamping pipelines after editing a config blueprint
  Config-driven: never hand-edit a generated pipeline; edit the blueprint and re-stamp.
---

# hso-pipeline-generation

Pipelines are **generated from config**, per ADR-0001 (config-driven generation) and ADR-0003 (token
contract). A project describes what it needs in the blueprints; the generator emits concrete YAML.

## The two blueprints (single source of truth)

| File | Governs |
|---|---|
| `ProjectTemplate/PipelinesHelpers/config/pipeline-defaults.json` | Project identity (`projectCode`, publisher, `solutionPrefix`), environments, ADO names/area |
| `ProjectTemplate/PipelinesHelpers/config/solution-organizer.json` | Solution layers and their deploy order |

## Workflow

1. **Edit the blueprint**, never a pipeline YAML directly. Trace the whole config chain (ADR-0003):
   a publisher-prefix change ripples to solution names, schema names, web-resource paths, and the
   client `webResourcePrefix`.
2. **Stamp** all pipeline YAML from config:
   ```powershell
   pwsh -File ProjectTemplate/PipelinesHelpers/scripts/Update-PipelineDefaults.ps1
   ```
   This writes the generated blocks (delimited by marker comments) across the pipeline set.
3. **Review the diff** — generated regions only; the marker blocks make hand-edits obvious.
4. **Never hand-edit generated regions** — `hso-generated-file-review` flags them; the next stamp
   overwrites them anyway.

## Rules

- Per-project variability lives in the blueprints, not in a YAML file.
- Environments: writes flow through the human-run release pipeline; the generator does not deploy.
- Adding a solution layer: (1) update `solution-organizer.json`, (2) re-stamp, (3) create the
  solution in the platform, (4) update step registrations if needed.

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-10 | maciejnowicki | Ported from HINT; neutralised to the ADR-0003 blueprint/token contract. |
