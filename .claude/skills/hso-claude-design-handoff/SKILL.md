---
name: hso-claude-design-handoff
layer: orchestration
scope: core
description: Package a Dataverse/D365 feature that has been skeletoned (data model + form skeleton + the as-is D365 behaviour it replaces) into a high-quality handoff brief for Claude Design (claude.ai/design), then reconcile Claude Design's runnable HTML/CSS/JS output back into a PCF control spec. Use for "hand this off to Claude Design", "prep a Claude Design brief", or taking a prototyped feature to claude.ai/design for first-class UX. Deliberately grants Claude Design latitude to redesign the experience and surface gaps; the return loop feeds hso-pcf-control-development.
---

# Claude Design Handoff

This skill runs the loop between a thin functional skeleton built in Dataverse and a
first-class UX produced in **Claude Design** (claude.ai/design):

1. **Skeleton** — we model the data and stand up a rough form/function in the dev
   environment, usually while migrating a screen or flow off an existing Microsoft
   D365 system.
2. **Hand off** — we package that skeleton plus the as-is context into a brief and give
   Claude Design **deliberate creative latitude** to design the experience properly and
   to tell us what we missed.
3. **Iterate together** — we refine on the canvas conversationally.
4. **Return** — we reconcile Claude Design's runnable output into a PCF control spec that
   feeds `hso-pcf-control-development`.

The brief is engineered to give Claude Design *context and intent*, not a pixel spec. We
are coming FROM a legacy system; the goal is a better experience, not a faithful clone.

## When to use this skill

- A feature already has a data model + form skeleton (or a rough functional prototype) in
  the dev environment, and you want first-class UX/UI before building the real control.
- You are migrating a screen/flow off an existing D365 (or other legacy) system and want a
  fresh, modern experience rather than a like-for-like rebuild.
- You explicitly want Claude Design to challenge assumptions and propose the flows, states,
  and edge cases the initial thinking missed.
- Trigger phrases: "hand this off to Claude Design", "prep a Claude Design brief", "take
  this to claude.ai/design", "get the UX done in Claude Design".

## When NOT to use this skill

- The UI is a standard model-driven form/view with no custom control needed → use
  `hso-dataverse-ui-config`.
- No skeleton/data model exists yet → model it first (`hso-dataverse-data-modeling`), or
  write the feature spec (`hso-dataverse-architect`).
- The design is already finalised and you just need to build → go straight to
  `hso-pcf-control-development`.
- You need a static visual asset (slide, diagram, ERD), not a product UI → use the diagram
  / reveal.js skills.

## What Claude Design is (orientation)

Claude Design (claude.ai/design) is an Anthropic Labs research-preview product. Relevant
facts that shape the brief:

- **Conversational + canvas.** Chat on the left, live canvas on the right. You describe;
  it generates.
- **Accepts:** a text prompt, images/screenshots, documents (DOCX, PPTX, XLSX), a linked
  **codebase**, and a **web-capture** tool that grabs elements from an existing site so the
  prototype looks like the real product.
- **Design system.** On setup it can read your codebase and design files to build a design
  system, then reuse your colours/typography/components automatically.
- **Output is real, runnable HTML/CSS/JS** — not a static mockup — with **handoff to Claude
  Code** (local or web). Exports: zip, PDF, PPTX, Canva, standalone HTML.
- **Iteration:** chat for structural/broad changes; inline comments + adjustment knobs for
  precise tweaks; it can run its own design review for accessibility/usability.

Links: [Get started](https://support.claude.com/en/articles/14604416-get-started-with-claude-design)
· [Announcement](https://www.anthropic.com/news/claude-design-anthropic-labs)

## Configuration

Read from `CLAUDE.md`: **Publisher Prefix** · **Default Solution** · **Environment URL** ·
**MCP Server** · **Language Code**
Read from `CLAUDE.local.md`: **Author Name** (brief attribution; never use an AI name)

If a value is missing, ask — do not guess.

## Data handling (MANDATORY)

Claude Design is an **external** tool. Before uploading anything:

- Upload only **anonymised / synthetic** sample data — never real customer PII, account
  numbers, financials, or confidential client records.
- **Scrub screenshots** of the legacy D365 system: redact real names, IDs, money values,
  and any client-identifying chrome.
- Confirm the engagement's data-handling policy permits sending schema/screenshots to
  claude.ai before doing so. When in doubt, *describe* the data shape rather than upload a
  live export.
- Prefer the field/entity **shape** (names, types, option-set labels) over real rows.

## Workflow

### Part A — Prepare the handoff (outbound)

1. **Gather context.**
   - Query the data model via MCP — `describe_table` for each entity; capture field logical
     names, types, option-set values, and relationships. **Never guess field names.**
   - Read the form skeleton / functional prototype so the data shape and intended flow are
     captured.
   - Capture the **as-is** D365 screen(s)/flow being replaced: screenshots (scrubbed) plus a
     short note on what works, what hurts, and why it is being replaced.
   - Collect a small set of **anonymised** representative data.
2. **Frame the problem.** Identify the *jobs to be done*, the *audience* (which
   roles/personas, on which devices), and the hard *constraints* (target host —
   model-driven PCF, Fluent v9 design language, performance envelope).
3. **Write the brief.** Create
   `agent/work/design/<Feature>_ClaudeDesign_Brief.md` from
   [references/handoff-brief-template.md](references/handoff-brief-template.md). Use the
   `type: design` frontmatter from the project schema (`agent/schema.md`).
4. **Assemble the asset checklist.** List every asset Claude Design should ingest with its
   repo path (scrubbed screenshots, schema table, anonymised sample data, brand/theme
   references). The template includes the checklist section.
5. **Produce the opening prompt.** Fill the ready-to-paste opening prompt from the template:
   goal + layout + content + audience, plus the **explicit freedoms** (redesign the UX,
   diverge from the legacy pattern, surface missing flows/states/edge cases).
6. **Log it.** Append a `design` entry to `agent/log.md`.

### Part B — At claude.ai/design (human-in-the-loop guidance)

Surface this guidance to the user; they drive the canvas:

- Create the project. **Attach the assets** from the checklist. If helpful, point Claude
  Design at the repo/codebase so it inherits the design system, and use web-capture against
  the live app for brand fidelity.
- Paste the **opening prompt**.
- Iterate: **chat** for structural changes, **inline comments** for precise tweaks. Ask it
  to **run a design review** (accessibility, usability) and to **offer 2–3 variations** when
  a direction is uncertain.
- Explicitly ask, every session: *"What flows, states, or edge cases are we missing?"* and
  *"Where would you deliberately diverge from the legacy D365 pattern, and why?"* — this is
  the whole point of the handoff.
- When satisfied, **export runnable HTML** (and/or use handoff-to-Claude-Code) and save the
  output into `agent/work/design/<Feature>/` (or `agent/raw/exports/` if treating it as an
  immutable source snapshot).

### Part C — Reconcile into a PCF spec (return loop)

1. **Bring the output back.** Save Claude Design's HTML/CSS/JS (and final screenshots) into
   the repo.
2. **Translate to a PCF spec.** Using
   [references/return-loop-to-pcf.md](references/return-loop-to-pcf.md) and the
   [PCF control spec template](../../../shared/dv/agent/wiki/reference/pcf-control-spec-template.md),
   map the design onto: control identity, binding/dataset, every required UI state, Fluent
   v9 component choices, accessibility, performance, and **feasibility flags** (anything
   Claude Design did that PCF cannot do cleanly — note the adaptation).
3. **Write the spec** to `agent/work/specs/<Feature>/<Feature>_Spec.md`.
4. **Hand to build.** Invoke `hso-pcf-control-development` to build from the spec; use
   `hso-dataverse-ui-config` to host the control on the form.
5. **Record divergences.** If the UX departed materially from the legacy system, capture an
   ADR via `hso-wiki-write-decision` so the rationale is durable.

## Critical rules

### DO

- Give Claude Design genuine latitude — context, goals, and constraints, **not** a pixel
  spec. Invite divergence from the D365 original.
- Always ask it to surface gaps, missing states, and edge cases.
- Anonymise all data and scrub all screenshots before upload.
- Query Dataverse metadata for the real field names/types/option-set values.
- Keep the brief in `agent/work/design/`; keep the reconciled spec in `agent/work/specs/`.
- Run Claude Design's output through the PCF spec template before any build starts.

### DO NOT

- Instruct Claude Design to "clone" or "rebuild exactly" the legacy D365 screen.
- Upload real client PII or confidential data to an external tool.
- Treat Claude Design's HTML as the deliverable — it is the **UX source**; the PCF control
  is the build target.
- Skip the feasibility pass (Fluent v9 / PCF platform constraints) when reconciling.

## Related skills

- `hso-pcf-control-development` — builds the control from the reconciled spec.
- `hso-dataverse-ui-config` — hosts the control on the form; standard form/view config.
- `hso-dataverse-data-modeling` — create/adjust the data model behind the skeleton.
- `hso-dataverse-architect` — full feature spec / approach decision when scope is larger.
- `hso-wiki-write-decision` — record material UX divergences as ADRs.

## References

- [references/handoff-brief-template.md](references/handoff-brief-template.md) — the brief
  structure + ready-to-paste opening prompt.
- [references/return-loop-to-pcf.md](references/return-loop-to-pcf.md) — translating Claude
  Design output into a PCF spec.
- [PCF control spec template](../../../shared/dv/agent/wiki/reference/pcf-control-spec-template.md) ·
  [pcf-controls topic](../../../shared/dv/agent/wiki/topics/pcf-controls.md) ·
  [ui-guidelines topic](../../../shared/dv/agent/wiki/topics/ui-guidelines.md)

## Changelog

| Date | Author | Description |
|------|--------|-------------|
| 2026-06-10 | keithwhatling | Initial creation — outbound Claude Design handoff brief + return-loop reconciliation into a PCF spec; data-handling guardrails; anchored to ui-guidelines / pcf-controls topics |
