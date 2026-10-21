---
name: aidevme-skill-recorder
metadata:
  layer: meta
  scope: core
description: |
  Turn a workflow the user demonstrated or described into a reusable, production-quality SKILL.md: redact
  secrets, reconstruct one intent and ordered steps, generalize, map UI clicks to CLIs and APIs, and show the
  full draft for approval before saving. Use when:
  (1) "record this as a skill", "turn what I just did into a skill", /aidevme-skill-recorder
  (2) "make a skill from these steps / this log / these screenshots / this narration"
  (3) "convert this Skill Recorder session into a Claude skill" (an intent + steps export)
  (4) "make a skill from what we just did" (the current conversation is the evidence)
  Accepts narration, terminal commands and output, screenshots, URL or window-title timelines, and Skill
  Recorder exports, in any mix. Does NOT write a skill from a bare idea with no demonstrated steps (use
  aidevme-skill-creator), record the screen itself, run the recorded task, or save anything before approval.
argument-hint: "[evidence: pasted log, file paths, or 'this conversation']"
---

# aidevme-skill-recorder: record a workflow as a skill

<!-- cspell:ignore pagetype entitylist -->

Ports the method of [skill-recorder](https://github.com/aidevme/skill-recorder) (a fork of microsoft/skill-recorder):
the user does a task once, the skill reconstructs **one intent** and an **ordered list of steps**, the user reviews
them, and a reusable SKILL.md is generated from one example. Work in the phases below, in order, and stop at each
gate.

## Principles

1. **Intent first, then ordered steps**, reconstructed from what the user actually did, not what they might do.
2. **Generalize from one example.** One form submitted becomes the procedure for all of them.
3. **Native tools over clicks.** Prefer `gh`, `az`, `pac`, the Dataverse Web API, REST APIs and MCP connectors to
   replaying UI steps ([ui-to-api-mapping.md](references/ui-to-api-mapping.md)).
4. **Human review gate.** Show the complete SKILL.md, frontmatter included, before saving. Any edit to the plan
   invalidates the preview.
5. **Secrets hygiene.** Nothing from the evidence that is a credential, identifier or customer data reaches the
   skill; it becomes a named parameter ([redaction-checklist.md](references/redaction-checklist.md)).

## Phase 1: Intake and redact

1. Collect the evidence the user points at, in any combination:

   | Evidence | How to read it |
   | --- | --- |
   | Narration or walkthrough | Verbs and objects become actions and targets; note the order words ("then", "after") |
   | Terminal commands and output | Commands are steps; output is the expected result and the verification |
   | Screenshots | Read each image; the visible page, field labels and buttons give target and inputs |
   | URL or window-title timeline | The host gives the system; the path gives the area (for example `/main.aspx?pagetype=entitylist`) |
   | Skill Recorder export | Read it as-is; its format isn't assumed. Ask when its structure is unclear |
   | "What we just did" | The current conversation: the tool calls and their results are the steps |

2. Redact before anything else, with [redaction-checklist.md](references/redaction-checklist.md): replace each
   secret or identifier with a `{{camelCaseName}}` placeholder and list what was removed (kind and placeholder, never
   the value). If anything secret was found, warn once that it was in the evidence and won't be in the skill.
3. **Too thin to order?** If the evidence doesn't show the steps or their order (one screenshot, a vague sentence),
   say what's missing and ask for more. Don't guess an order.

## Phase 2: Reconstruct (gate)

Present this **analysis** and ask the user to approve or edit it. Write no skill before approval.

- **Intent:** one sentence, the goal and not the clicks ("Register a new plug-in step on the Account update message").
- **Steps**, in order, each with:

  | # | Action | Target system | Inputs | Expected result |
  | --- | --- | --- | --- | --- |

- **Variables:** what changes between runs, as parameters (`{{solutionName}}`, `{{environmentUrl}}`), with an
  example value only when it isn't sensitive.
- **Preconditions:** sign-ins, licenses, roles, environment, tools and versions the run needed.
- **Removed from the evidence:** the redaction list from Phase 1.

If the user edits the analysis, show the updated analysis again before moving on.

## Phase 3: Generalize

1. Find the **loop or batch form**: the step that repeated, or the one item that stands for many (one record, one
   repository, one environment). Describe the procedure for N items.
2. List **edge cases** (item missing, already done, partial failure), **failure points** (auth, throttling,
   locks, timeouts) and **verification checks** (what proves each step worked).
3. Ask **at most three** clarifying questions, only about things the evidence can't answer (for example "Should it
   stop at the first failure or continue with the next record?"). Use sensible defaults for the rest and say
   which defaults you picked.

## Phase 4: Map tools

For every UI step, propose its native equivalent from [ui-to-api-mapping.md](references/ui-to-api-mapping.md): a
CLI command, a REST or Web API call, an SDK call, or an MCP connector the user has. Rules:

- Check every command and endpoint against its documentation or `--help` before it goes into the skill. Never
  invent a flag, endpoint or connector.
- Keep a UI step only where no API exists; mark it **fragile (UI)** in the procedure, with what to look for on screen.
- For Dynamics 365 CE, Power Platform, Dataverse, Copilot Studio, PCF and Azure DevOps, prefer `pac`, the Dataverse
  Web API and `az` over maker-portal clicks.
- Show the mapping as a table (step, recorded action, proposed tool, fragile yes/no) in the next preview.

## Phase 5: Draft the SKILL.md

Write it from [skill-template.md](references/skill-template.md):

- **Folder and `name`:** kebab-case, describing the task (`register-plugin-step`), never containing "claude" or
  "anthropic". In a repository with its own naming rule (this one: `aidevme-<domain>-<purpose>`), follow that rule.
- **`description`:** what it does, a "Use when" list of trigger phrases, and a "Does NOT" clause. It's what decides
  whether the skill fires, so make it specific.
- **Body:** purpose, prerequisites, parameters, numbered procedure, **Verify**, error handling, and a short worked
  example with placeholder values. Imperative, concise, no marketing language.
- **Long material** (lookup tables, payload samples, scripts) goes to `references/` or `scripts/`, linked from the
  body, so SKILL.md stays short.
- **Destructive or irreversible steps** (delete, overwrite, publish or import to production, send email or
  messages, merge, deploy) get an explicit confirmation step inside the procedure that names the target and scope.
  No generated skill runs one without it.
- **Every generated skill ends its procedure with a Verify section** that proves the task succeeded (a query, a
  status check, a `show` command), not "check it worked".

## Phase 6: Review gate and save

1. Show the **complete SKILL.md**, frontmatter included, plus the list of any `references/` and `scripts/` files,
   read-only. Ask for explicit approval.
2. If the user changes the plan (intent, steps, parameters, tools) instead, go back to the phase that owns the
   change, regenerate, and show the new preview. Don't patch a preview the user hasn't seen.
3. On approval, save it:
   - **In a repository whose skills come from a single source** (this one: `agent-src/` with `aidevme-skill-creator`),
     hand the approved draft to **aidevme-skill-creator**. It chooses scope and group, writes `evals/evals.json`,
     registers the manifest, validates and syncs. Don't place files in the generated `.claude/skills` or
     `.github/skills` folders yourself.
   - **Elsewhere**, ask where it goes (the project's `.claude/skills/<name>/`, or the user's `~/.claude/skills/<name>/`)
     and write the folder: `SKILL.md`, plus `references/` and `scripts/` when used.
4. Report the files written and how to invoke the skill (`/<name>` or its trigger phrases).

## Phase 7 (optional): Scheduled automation

If the task recurs (daily export, weekly report, per-sprint cleanup), offer, as a separate step, to describe it as
a scheduled task: **cadence**, **inputs** (the parameters and where their values come from), **output** (file,
record, message), **notification** (who hears about success and failure), and the **confirmation policy** for any
destructive step. Write the description only; set up no schedule unless the user asks.

## Phase 8 (optional): Trigger evals

Offer 3 to 5 test prompts for the new skill's `description`: some that **should trigger** it (phrasings from the
recording) and some that **should not** (a sibling task, a similar word in another context). In a repository with
an `evals/evals.json` convention, these go there.

## Guardrails

- **No secrets or customer data** in the skill, its examples, its references or its evals: placeholders only
  (`{{environmentUrl}}`, `{{tenantId}}`, `{{accountName}}`).
- **No unconfirmed destructive actions** in a generated procedure (Phase 5).
- **No guessed order:** thin evidence means asking for more (Phase 1).
- **No invented tools:** every command, flag and endpoint is checked (Phase 4).
- **Nothing saved before approval** (Phase 6), and nothing run: this skill writes skills, it doesn't perform the task.

## Example

The user pastes this narration: "I opened make.powerapps.com, picked the Contoso Dev environment, went to Solutions,
selected SalesCore, clicked Export, chose Managed, and downloaded SalesCore_1_2_0_0_managed.zip into the build folder."

1. **Redact:** "Contoso Dev" becomes `{{environmentUrl}}` (an environment name), SalesCore becomes `{{solutionName}}`;
   the warning says one environment name and one solution name were replaced.
2. **Analysis:** intent "Export a solution as managed into a build folder"; four steps (pick environment, open the
   solution, export managed, save the zip); variables `{{environmentUrl}}`, `{{solutionName}}`, `{{outputFolder}}`;
   preconditions: a Power Platform sign-in with export rights, `pac` installed.
3. **Generalize:** the batch form exports several solutions in order; edge cases: unpublished customizations,
   solution missing. One question: "Publish all customizations before exporting?"
4. **Map:** the four clicks become `pac auth create --environment {{environmentUrl}}` and
   `pac solution export --name {{solutionName}} --path {{outputFolder}} --managed`; nothing fragile is left.
5. **Draft and review:** the preview shows `export-managed-solution/SKILL.md`, whose Verify step checks that the zip
   exists and that `pac solution list` shows the solution's version; saved after approval.

## Changelog

| Date | Author | Description |
| --- | --- | --- |
| 2026-10-21 | aidevme | Created: intake and redaction, reconstruction gate, generalization, UI-to-API mapping, drafting from a template, review gate with hand-off to aidevme-skill-creator, optional schedule and trigger evals; references for the template, redaction checklist and UI-to-API mapping. Ported from the skill-recorder method. |
| 2026-10-21 | aidevme | New [CHANGELOG.md](CHANGELOG.md): the skill's full history from its commits. |
