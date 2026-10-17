<!--
  GENERATED FILE — DO NOT HAND-EDIT.
  Source: AGENTS.md (body) + agent-src/sync/preambles/claude.md (this preamble).
  Regenerate with:  pwsh -File agent-src/sync/sync.ps1
  Any manual edit here is overwritten on the next sync and flagged by verify-parity.ps1.
-->

# CLAUDE.md

> This file is **generated** for **Claude Code** from `AGENTS.md`. Edit `AGENTS.md`, then run
> `pwsh -File agent-src/sync/sync.ps1`. Machine-specific settings live in `CLAUDE.local.md`
> (gitignored, per developer).

<!--
  This is the shared body of the AI-assistant instructions. The single SOURCE is AGENTS.md at the
  repo root; CLAUDE.md and .github/copilot-instructions.md are GENERATED from it by
  agent-src/sync/sync.ps1 (a tool-specific preamble is prepended to each at sync time). Make edits in
  the root AGENTS.md and re-run the sync — never in a generated copy.
-->

# Project Instructions (AGENTS.md)

<!-- cspell:ignore customapiresponseproperties fetchxml -->

The one instruction source for every AI coding assistant on this repo. It's fanned out to each tool's native
location by `agent-src/sync/sync.ps1`; only a short preamble differs per tool.

## 1. Repository overview

This repo hosts individual tools that plug into **Power Platform ToolBox (PPTB)**, following the same model as
XrmToolBox plugins: each tool under `tools/<tool-name>/` is a self-contained add-in for working with Microsoft
Dataverse / Power Platform. Each tool has its own `package.json`, build, and docs; there is no repo-wide build or
test command. `README.md` at the repo root indexes all tools, and `PLAN.md` tracks the plan and open work.

New tools are frequently **ports of existing XrmToolBox plugins or CLIs** (see
`.github/ISSUE_TEMPLATE/tool_port_request.yml`), reimplemented against PPTB's APIs rather than copied wholesale.
Check the tool's README for the original it's based on, what was intentionally left out of scope, and its credits.

### Documentation

- **Docs site:** VitePress in `docs/`, published to GitHub Pages. `npm run docs:build` (repo root) fails on dead
  links; run it after changing docs. New pages must be added to the sidebar in `docs/.vitepress/config.mts`.
- **Markdown checks:** after editing Markdown, run markdownlint and cspell through the `aidevme-docs-maintenance`
  skill (`Validate-Markdown.ps1`); it also maintains `cspell.json` and the `docs/` entries in `.github/CODEOWNERS`.
- **Per tool:** `docs/pptb-tools/<tool-name>/`, split into a **user guide** (`getting-started/`, `guide/`) and a
  **contributor guide** (`contributing/`, `architecture/`, `components/`). `tools/<tool-name>/README.md` holds
  implementation notes.
- **Repository:** `docs/repository/` (for example GitHub Agentic Workflows); `docs/todos/` holds working notes.

## 2. Shared tool conventions

Every tool is React + TypeScript + Fluent UI v9 (`@fluentui/react-components`), built with Vite. Run these from the
tool's own folder:

```bash
npm install
npm run dev      # Vite dev server, for iterating in a regular browser tab (PPTB APIs are absent)
npm run build    # tsc typecheck + vite build -> dist/ (single IIFE bundle)
npm run watch    # rebuild dist/ on change
npm test         # only where the tool's package.json defines it
npm run validate # pptb-validate, the PPTB manifest checks
```

`npm run build` (which runs `tsc`) is the correctness check to run after changes; also run `npm test` when the tool
has one. There is no lint script.

To test inside PPTB itself: build, then in PPTB enable the Debug Menu in Settings, use Debug → Browse to point at
the tool's directory (or `dist`), connect to a Dataverse environment, and reopen the tool tab after each rebuild.
Record live test results in the tool's `docs/pptb-tools/<tool-name>/contributing/testing.md`.

### Build constraint that shapes `vite.config.ts`

PPTB loads tools from a local folder (often `file://` or an iframe `srcdoc`), where `<script type="module">` can
fail to execute. Each tool's `vite.config.ts` has a custom `fixHtmlForPPTB` plugin that strips
`type="module"`/`crossorigin` from the built HTML and moves script tags to the end of `<body>`; the Rollup output
format is forced to `iife` with `inlineDynamicImports: true` so the whole app ships as one script. Don't reintroduce
code-splitting or ESM output: it breaks loading inside PPTB even though `npm run dev` still works.

### Marketplace policies

Tools are published to the PPTB marketplace, so they must meet its
[marketplace](https://docs.powerplatformtoolbox.com/policies/marketplace) and
[AI-assisted development](https://docs.powerplatformtoolbox.com/policies/ai-assisted-development) policies:

- A tool that changes Dataverse or the user's files previews the change, confirms it naming the target and scope,
  and documents every kind of change in its README's `## What this tool changes` section. Nothing destructive runs
  on load.
- Use only documented `toolboxAPI` / `dataverseAPI` / `powerplatformAPI` calls; declare every external domain in
  `cspExceptions`.
- Test live in PPTB, in light and dark themes, including error paths, before claiming something works.
- The `intake-policy-review` skill (and the `pptb-intake-review` agentic workflow) reviews a tool against these.

## 3. Dataverse Early-Bound TypeScript Generator (`tools/dataverse-early-bound-typescript-generator/`)

Generates early-bound TypeScript types and metadata for Dataverse tables, actions and functions. A port of Scott
Durow's [dataverse-gen](https://github.com/scottdurow/dataverse-gen) CLI: its output works with
[dataverse-ify](https://github.com/scottdurow/dataverse-ify) and it shares the `.dataverse-gen.json` project file.
Docs: `docs/pptb-tools/dataverse-early-bound-typescript-generator/`.

```text
src/
├── main.tsx           # theme; renders components/apps/App.tsx
├── core/              # pure TS: no PPTB, no I/O, no DOM-UI (DOMParser only for the CSDL)
├── services/          # PPTB adapters: dataverseAPI metadata, toolboxAPI file system, write planning
├── config/            # the tool's own settings (ToolConfig): defaults, normalization, project versioning
├── hooks/             # the state (no state management library): useToolSettings, useProject,
│                      # useEnvironmentMetadata, usePlanState, usePreviewGenerate, useSettingsDraft, ...
├── components/        # apps/App.tsx wires the hooks together and renders the cards; the other folders are
│                      # presentational and receive data/callbacks from App as props
├── assets/            # dataverse-gen's EJS templates, bundled as raw text
├── styles/            # one makeStyles hook file per component
└── types/
test/                  # vitest: dataverse-gen fixtures + the real CLI's reference output
```

Things that aren't obvious from a single file:

- **Output must match dataverse-gen byte for byte**, apart from the deliberate deviations listed in the tool's
  README (including the optional *Rename duplicated identifier(s)*). The EJS templates are reimplemented as plain
  functions in `core/templates.ts` (EJS's `new Function` is blocked by the PPTB iframe CSP), and
  `test/generator.test.ts` compares the output against `test/reference/`. Keep `test/reference/` and
  `test/fixtures/` in LF line endings: a CRLF checkout makes those tests fail.
- **dataverse-gen's original templates are also written to projects.** `src/assets/dataverse-gen-templates/*.ejs`
  (2.0.17, byte for byte, protected by `.gitattributes`) go to the project's `templateRoot` (`_templates`) on every
  Generate, like `dataverse-gen eject`. The tool never reads them.
- **Each folder has an `index.ts` barrel** (`components`, `hooks`, `services`, `core`, `config`, `types`, `styles`). Add new
  exports there. Inside `services/`, files import each other directly rather than through the barrel, to avoid cycles.
- **Private custom APIs aren't in `$metadata`.** They're still listed; their definitions are built from the
  `customapi` record, its `customapirequestparameters`, and its `customapiresponseproperties` (the `<Name>Response`
  complex type).
- **File statuses.** The write plan marks generated files `new`, `changed`, `unchanged`, `orphaned`, or
  `duplicate` (an enum with two members of the same name); `writeStatusOf` / `willWrite` / `writeCounts` in
  `services/plan.ts` say what Generate actually writes. Use them rather than counting statuses directly.
- **Orphaned files are deleted only on opt-in.** They're reported by default and removed only when the user turns
  on *Delete orphaned files* and confirms the list. PPTB's file API has no delete, so deletion runs through a hidden
  PPTB terminal (`PptbFileSink.deleteFiles`), and `deleteOrphanedFiles` in `services/plan.ts` guards which paths
  reach it.
- **Settings that appear in two places** (the Settings panel and the Preview card) share one explanation in
  `components/shared/settingsInfo.tsx` and save the same tool-config key.

## 4. The agent layer

### Skills and subagents: single source, generated copies

Skills and subagents are authored once under `agent-src/` and generated into each assistant's location:

- `agent-src/skills/core/<group>/<name>/`: reusable skills. `agent-src/skills/project/<group>/<name>/`: skills
  specific to this repo (the PPTB skills live in `project/pptb/`).
- `agent-src/agents/<name>.md`: subagents.
- `agent-src/sync/skills-manifest.json`: every skill's `scope` (`core` | `project` | `drop`) and whether it's on
  disk (`ported`). Removed skills stay recorded as `drop`.

**Generated, never hand-edited:** `.claude/skills/`, `.github/skills/`, `.claude/agents/`, `.github/agents/`,
`CLAUDE.md` and `.github/copilot-instructions.md`. Edit the source, then:

```bash
pwsh -File agent-src/sync/sync.ps1 -DryRun   # see what would change
pwsh -File agent-src/sync/sync.ps1           # regenerate (it deletes and recreates the generated folders)
pwsh -File agent-src/sync/verify-parity.ps1  # must pass
```

New skills use the `aidevme-` prefix (`aidevme-<domain>-<purpose>`) and are created with `aidevme-skill-creator`.

### Installed skills

| Skill | Use when |
| --- | --- |
| `pptb-tool-dev` | Building, debugging, validating or publishing a PPTB tool |
| `intake-policy-review` | Checking a tool against the PPTB marketplace and AI-assisted development policies |
| `tool-verification` | Checking a tool against the Verified badge requirements |
| `aidevme-pptb-tool-refactoring` | Analyzing tools and proposing a refactoring plan, then executing only the approved steps (report saved to `docs/todos/`) |
| `aidevme-pptb-tool-developer` | Moving inline `makeStyles` hooks out of a tool's components into `src/styles/<ComponentName>.styles.ts` (`use<ComponentName>Styles`) |
| `playwright-cli` | Driving a browser: testing, screenshots, scraping |
| `aidevme-dataverse-sdk-reference` | Dataverse SDK / Web API / metadata reference |
| `aidevme-fetchxml-queries` | Writing or optimizing FetchXML |
| `aidevme-dataverse-data` | Querying or changing Dataverse records through the Web API |
| `aidevme-dataverse-customapi` | Creating or inspecting Custom APIs (for example to test the generator) |
| `aidevme-shared-scripts` | Shared auth and Web API scripts the Dataverse skills load; not run directly |
| `aidevme-diagram-drawio` | draw.io diagrams for the docs |
| `aidevme-wiki-*` | The `agent/` wiki: `capture`, `lint`, `process-inbox`, `query`, `scaffold-project`, `update-topic`, `write-decision` |
| `aidevme-skill-creator`, `skill-creator` | Creating or improving skills |
| `aidevme-skills-sync` | Checking that the generated skill folders match the source |
| `aidevme-docs-maintenance` | Validating Markdown (markdownlint + cspell), syncing `cspell.json`, syncing the `docs/` entries in `.github/CODEOWNERS` |

### The `agent/` wiki

Project knowledge lives in `agent/`, a four-layer wiki; the rules are in [`agent/schema.md`](agent/schema.md):

- `raw/`: immutable sources (read, never edited); `_inbox/`: drop zone, routed by `aidevme-wiki-process-inbox`.
- `wiki/`: durable knowledge (topics, decisions, digests, references, system state).
- `work/`: project deliverables by phase (analysis, specs, design, build, testing, deliverables).

Record load-bearing decisions as ADRs in `agent/wiki/decisions/` (`aidevme-wiki-write-decision`).

## 5. Working principles

- **Ask before assuming.** When scope, behavior or acceptance criteria are ambiguous, ask before implementing.
- **Problem-solving protocol.** On an unexpected error: stop, explain what you observed and your hypothesis, propose
  options with trade-offs, and wait for a decision before acting. No one-off workaround scripts.
- **Surgical changes.** Touch only what the task needs, match the surrounding style, and mention unrelated issues
  separately instead of fixing them.
- **Verify before saying it's done.** Build, run the tests, and say plainly what wasn't verified (for example,
  anything that needs a live PPTB host).
- **Keep docs and comments accurate.** Update the tool's docs, README and TSDoc in the same change as the behavior;
  a comment must match the code it describes.
- **Never invent APIs or metadata.** Check the PPTB API reference and live Dataverse metadata rather than guessing.

## 6. Commits

Follow the Conventional Commits format in [`CONTRIBUTING.md`](CONTRIBUTING.md) (`<type>(<scope>): <subject>`).
Don't commit unless asked; keep unrelated changes in separate commits.

## 7. Windows reserved filenames

Never redirect output to `nul`: it creates a real file that only `git bash rm` can delete. Use `2>$null`
(PowerShell) or `-ErrorAction SilentlyContinue`. Avoid `CON`, `PRN`, `AUX`, `NUL`, `COM1`-`COM9`, `LPT1`-`LPT9`.

## 8. Maintenance

Update **this file** (`AGENTS.md`), never the generated `CLAUDE.md` / `.github/copilot-instructions.md`, and re-run
`agent-src/sync/sync.ps1` when adding a tool, changing build or test processes, adding or removing skills, or
making architectural changes.
