# DEVELOPER

![A glowing open toolbox labelled "Shared instructions, better outcomes" releases three skill cards: teal "Build, fix, create" with a wrench and code brackets, amber "Review, assess, improve" with a magnifying glass over a document, and green "Verify, validate, trust" with a shield and checkmark. Each card is linked to an AI assistant orb above, with SKILL.md panels floating on a dark blue background](assets/pptb-tools-developer-preview.png)

## AI Agent Skills

Power Platform ToolBox publishes [pptb-agent-skills](https://github.com/PowerPlatformToolBox/pptb-agent-skills), a
set of skills that help AI coding assistants build, review and verify PPTB tools. They use the open `SKILL.md`
format, so Claude Code (and Cowork), GitHub Copilot and OpenAI Codex all read the same files. The skills are based
on the PPTB documentation, the marketplace policies and the `generator-pptb` scaffolding tool.

Source: [AI Agent Skills](https://docs.powerplatformtoolbox.com/tool-development/ai-agent-skills) in the PPTB
documentation. Check it for updates; the skills and the PPTB APIs they describe change over time.

### The skills

| Skill | Install as | What it does |
| --- | --- | --- |
| [`tool-dev`](https://github.com/PowerPlatformToolBox/pptb-agent-skills/tree/main/tool-dev) | `pptb-tool-dev` | Scaffolds, fixes, debugs, validates and publishes PPTB tools. |
| [`intake-policy-review`](https://github.com/PowerPlatformToolBox/pptb-agent-skills/tree/main/intake-policy-review) | `intake-policy-review` | Reviews a tool against the Marketplace Policy and the AI-Assisted Development Policy, and gives a readiness verdict. |
| [`tool-verification`](https://github.com/PowerPlatformToolBox/pptb-agent-skills/tree/main/tool-verification) | `tool-verification` | Checks a tool repository against the current Verified badge criteria. |

What each one covers:

- **`tool-dev`**:
  - scaffolding with `yo pptb`;
  - fixing `package.json` and `pptb.config.json` until `pptb-validate` passes (here: `npm run validate`);
  - letting other PPTB tools launch a tool (`launchTool`, `getLaunchContext`, `returnData`);
  - exposing a tool to agents through MCP (the `agents` block and `invokeHeadless`).
- **`intake-policy-review`**:
  - metadata;
  - read/write safety and the required "What this tool changes" README section;
  - API usage;
  - privacy and network behaviour;
  - screenshots;
  - testing;
  - a dependency audit.
- **`tool-verification`**:
  - Checks every required and optional maturity criterion.
  - Produces a criterion-by-criterion evidence table, notes on missing evidence, and a "Reviewer response" list
    for the verification form.
  - Verdicts: *Ready to request verification*, *Needs reviewer judgment*, *Not ready* or *Incomplete assessment*.

### Prerequisites

- Node.js and npm.
- The PPTB desktop app, for the debug loop (Debug → Browse). Scaffolding and validation don't need it.
- Claude Code or Cowork, GitHub Copilot, or OpenAI Codex, with skills enabled.
- For the review skills: access to the tool's repository and the policies, plus dated evidence from the tool's
  owner for any marketplace metrics.

### Installing the skills in this repository

This repository uses Claude Code, so project skills go in `.claude/skills/` (alongside the existing ones). From
Bash or Git Bash, in the repository root:

```bash
git clone https://github.com/PowerPlatformToolBox/pptb-agent-skills.git ../pptb-agent-skills

cp -r ../pptb-agent-skills/tool-dev/ .claude/skills/pptb-tool-dev/
cp -r ../pptb-agent-skills/intake-policy-review/ .claude/skills/intake-policy-review/
cp -r ../pptb-agent-skills/tool-verification/ .claude/skills/tool-verification/
```

Copy each whole skill folder, including any `references/` folder inside it. Note that `tool-dev` is installed under
the name `pptb-tool-dev`.

For the other assistants, copy the same folders to:

| Assistant | Skills folder |
| --- | --- |
| Claude Code / Cowork | `<project>/.claude/skills/` |
| GitHub Copilot | `<repo>/.github/skills/` |
| OpenAI Codex | `<repo>/.agents/skills/` (create it first with `mkdir -p`) |

### Example prompts

- "Scaffold a PPTB tool for bulk-updating account records."
- "This `package.json` fails `pptb-validate`; fix it."
- "Let other PPTB tools launch this tool."
- "Expose this tool to an agent through MCP."
- "Review `tools/dataverse-early-bound-typescript-generator` for marketplace intake readiness."
- "Check this repository against all Verified badge requirements."

### Scope and limitations

- **Scaffolding:** `tool-dev` scaffolds only with `generator-pptb`. It doesn't use the older
  [sample-tools](https://github.com/PowerPlatformToolBox/sample-tools) repository.
- **Example repository:** `Power-Maverick/PPTB-Tools` is used only as an example of patterns, not as a template.
- **Approval:** the skills don't replace marketplace approval or human testing. They can't grant a Verified badge
  or a reviewer waiver.
- **Maturity:** `tool-dev` isn't tested end to end yet. Its agent-integration guidance may describe APIs newer than
  the PPTB version you have installed, so validate generated code. In this repo, that means `npm run build`,
  `npm test` and `npm run validate` in the tool's folder, then a test in PPTB.
