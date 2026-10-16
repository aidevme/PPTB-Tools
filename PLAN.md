# PPTB Tools: Plan and Progress Tracker

<!-- cspell:ignore negotiables unscanned -->

> **Mission.** Build and publish high-quality tools for [Power Platform ToolBox](https://www.powerplatformtoolbox.com/)
> (PPTB): XrmToolBox-style add-ins for Microsoft Dataverse and the Power Platform, often ports of proven
> XrmToolBox plugins or CLIs reimplemented on PPTB's APIs.
>
> **Non-negotiables:** each tool passes the PPTB marketplace and AI-assisted development policies before
> submission · tested live in PPTB against a real environment, not only with mocks · docs match the current
> behavior · ported code keeps its original credit and license.

**Owner:** Zsolt Zombik · **Repository:** [aidevme/PPTB-Tools](https://github.com/aidevme/PPTB-Tools) (public) ·
**Docs site:** [aidevme.github.io/PPTB-Tools](https://aidevme.github.io/PPTB-Tools/) · **Last updated:** 2026-10-15

---

## Tools

| Tool | Folder | Version | Status | Next milestone |
| --- | --- | --- | --- | --- |
| **Dataverse Early-Bound TypeScript Generator** (port of Scott Durow's dataverse-gen) | [`tools/dataverse-early-bound-typescript-generator`](tools/dataverse-early-bound-typescript-generator/) | 1.0.0 | Built, mostly live-tested, intake review 🟡 | Marketplace submission |

Legend: ⬜ not started · 🔄 in progress · ✅ done

---

## 1. Dataverse Early-Bound TypeScript Generator: marketplace submission

Latest automated intake review: issue #14, run
[38713904682](https://github.com/aidevme/PPTB-Tools/actions/runs/38713904682), verdict **🟡 Very close / minor
changes**, no blockers.

### Live testing ([testing record](docs/pptb-tools/dataverse-early-bound-typescript-generator/contributing/testing.md))

| Check | Status |
| --- | --- |
| Load, connect, list tables (~2,900), projects, selection, Settings panel, Preview | ✅ 2026-10-13/14 |
| Generate: write new and changed files | ✅ 2026-10-15 |
| Delete orphaned files (Windows) | ✅ 2026-10-15 |
| Dark theme | ✅ 2026-10-15 |
| Error paths: no permission, expired connection | ⬜ |
| Following a theme switch while the tool is open | ⬜ |
| Orphan deletion on macOS / Linux | ⬜ |
| Bulk option-set query against a live host | ⬜ (marked unverified in the README) |
| Large-`$metadata` fallback against an environment over 16 MiB | ⬜ (marked unverified in the README) |

### Before submitting

From the intake reviews (local review and issue #14):

- [ ] Finish the open live-testing checks above, error paths first: the AI-assisted development policy requires them.
- [ ] Recapture `docs/assets/dataverse-early-bound-typescript-generator/gs-load-tool.png` without the client
      environment and project names it shows.
- [ ] Add an **AI assistance** section to the tool README (required if the code is substantially AI-assisted).
- [ ] Make the tool README's three `../../docs/...` links absolute: PPTB renders the README from `readmeUrl`,
      where relative links break.
- [ ] Decide whether **Ask before generating** (`confirmBeforeGenerate`) should be on by default. It's `false`
      now, so overwrites aren't confirmed unless the user turns it on.
- [ ] Get confirmation that deleting orphans through a hidden PPTB terminal is acceptable to the reviewers.
- [ ] Run `npm run finalize-package` (creates `npm-shrinkwrap.json`, which `files` lists), then `npm audit`,
      `npm run validate`, and test the packaged `dist/` in PPTB.
- [ ] Rerun the intake review workflow and get a 🟢 verdict.
- [ ] Publish to npm and submit to the PPTB marketplace.

### Backlog (after submission)

| Item | Status | Plan |
| --- | --- | --- |
| Settings panel P2 and P3 settings | 🔄 P1 done 2026-10-14 | [settings-panel](docs/todos/dataverse-early-bound-typescript-generator-settings-panel.md) |
| Documentation screenshots | ⬜ | [documentation](docs/todos/dataverse-early-bound-typescript-generator-documentation.md) |
| Bundle-size warning (967 kB single chunk) | ⬜ | [npm-optimization](docs/todos/dataverse-early-bound-typescript-generator-npm-optimization.md) |
| General refactoring | ⬜ | [refactoring](docs/todos/dataverse-early-bound-typescript-generator-general-reactoring.md) |

---

## 2. New tools

For each new tool:

1. Open a **Tool Port Request** issue (`.github/ISSUE_TEMPLATE/tool_port_request.yml`): the source plugin, its
   license, the features to port and what's out of scope.
2. Design: check the PPTB APIs it needs and any `cspExceptions`, and record the decision in
   `agent/wiki/decisions/`.
3. Build in `tools/<tool-name>/` with the shared conventions (React + TypeScript + Fluent UI v9, Vite, single
   IIFE bundle; see [CLAUDE.md](CLAUDE.md)).
4. Test live in PPTB, and keep the testing record under `docs/pptb-tools/<tool-name>/contributing/testing.md`.
5. Write the user guide and contributor guide under `docs/pptb-tools/<tool-name>/` and add the tool to the
   VitePress sidebar and the root README.
6. Add the tool to the intake review workflow's `tool` options and run it until the verdict is 🟢.

---

## 3. Repository automation (GitHub Agentic Workflows)

Guide: [docs/repository/agentic-workflows.md](docs/repository/agentic-workflows.md) · Workflow reference:
[docs/todos/github-agentic-workflows.md](docs/todos/github-agentic-workflows.md)

| Item | Status |
| --- | --- |
| PPTB marketplace intake review workflow (`.github/workflows/pptb-intake-review.md`) | ✅ Runs and creates the review issue |
| Agentic Workflow issue template, and review issues in its layout | ✅ Committed; the new layout hasn't run yet |
| **Threat detection** | 🔄 Fails on every run, so review issues are published unscanned (tracked by gh-aw in issue #15) |

**Threat detection, next action.** The first failure (model alias `detection`) is fixed. The second run
failed differently: the `sonnet` alias resolved to `claude-sonnet-5-5`, which gh-aw's API proxy rejects with
`400 Model "claude-sonnet-5-5" has no AI credits pricing`. The main agent uses `claude-sonnet-5` and works.
Proposed fix: set `safe-outputs.threat-detection.engine.model` to `claude-sonnet-5`, recompile, rerun, and
confirm issue #15 gets no new comment.

Ideas, in order (each starts read-only and reports to an issue):

- [ ] **CI doctor:** when a tool's build workflow fails, investigate and open an issue.
- [ ] **Docs sync:** when a tool's `src/` changes, propose updates to its docs.
- [ ] **Issue triage:** label new issues and ask for missing details.

---

## 4. AI agent setup

| Item | Status |
| --- | --- |
| Single-source skill sync (`agent-src/` → `.claude/skills` and `.github/skills`) | ✅ Committed 2026-10-15 |
| `agent/` project wiki scaffold | ✅ Committed; no content yet |
| Skill set trimmed to PPTB tool development: 63 skills dropped, 20 kept; PPTB skills moved into `agent-src/skills/project/pptb/` | ✅ 2026-10-15; `verify-parity.ps1` passes except `CLAUDE.md` |
| `AGENTS.md` (source for `CLAUDE.md` and `.github/copilot-instructions.md`) | ✅ 2026-10-16: rewritten for this repo, sync run, `verify-parity.ps1` passes with zero drift |
| Skills renamed from `hso-*` to `aidevme-*` | ✅ 2026-10-16 |

Still open:

- [ ] Decide on commit attribution. `AGENTS.md` now only points to `CONTRIBUTING.md`'s commit format; it neither
      requires nor forbids crediting an AI assistant, while recent commits carry a `Co-Authored-By: Claude` line.

---

## 5. Documentation site

| Item | Status |
| --- | --- |
| VitePress site, published by `.github/workflows/docs-pages.yml` | ✅ |
| Generator docs split into a user guide and a contributor guide | ✅ 2026-10-14 |
| Repository section (agentic workflows guide) | ✅ |
| `docs/todos/` pages | Built but not in the sidebar; internal working notes |
| Pages for the new tools | ⬜ With each tool |

---

## Decisions

Record material decisions as ADRs in [`agent/wiki/decisions/`](agent/wiki/decisions/). Decisions made so far,
still to be written up:

- [ ] The intake review runs on demand only, reports one issue per run, and closes older reviews.
- [ ] Repository secrets (not a GitHub environment) for `ANTHROPIC_API_KEY`.
- [ ] Single-source skill sync from `agent-src/` for Claude Code and GitHub Copilot.
