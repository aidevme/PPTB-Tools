---
name: hso-presales-demo-architect
layer: orchestration
scope: core
description: |
  Create presales demo artifacts: Demo Outline (high-level summary), Presenter Clickpath (deep reference guide), and Demo Master Script (choreographed present-from doc). Use when:
  (1) User asks to "create a demo outline", "write a clickpath", "build a presenter guide", "create the master script", or "script the demo"
  (2) User asks to update or refine an existing DemoOutline.md, Presenter_Clickpath.md, or Demo_Master_Script.md
  (3) User has a new client scenario and wants demo flow artifacts
  (4) User says "create the demo artifacts" or "document the demo"
  Does NOT build, configure, or seed demo data — that belongs to development/data skills.
---

# Presales Demo Architect Skill

Creates up to three complementary demo flow artifacts from discovery context and scenario knowledge:

- **DemoOutline** — concise section-by-section overview for internal alignment and exec review
- **Presenter Clickpath** — full presenter guide with SHOW/CLICK THROUGH/SAY structure, timing, and Q&A prep; for a live demo it becomes the **deep reference** (Q&A, recovery moves, record/URL table, build notes)
- **Demo Master Script** *(for live-presented demos)* — the single **present-from** document: run-of-show + word-for-word choreography (SAY + CLICK), tab map, hard time-ceiling with cut/restore order. See [references/master-script-template.md](references/master-script-template.md)

📎 **Demo data fidelity** — principles for a believable live demo (plausible numbers for the demo *date*, time-anchored timers/SLAs, **primary app & form selection**, **subgrid-driven data review**, **demo-owned record stamping**, persona casting, beat-value test, doc-sync discipline): [references/demo-data-fidelity.md](references/demo-data-fidelity.md). The seeding/config *mechanics* live in the development/data skills — including **Sales Insights Assistant / "Up Next" insight cards** (seeded as `actioncard`s; recipe in `hso-dataverse-data`).

---

## Step 1: Load Discovery Context

Before generating any artifacts, read available context in this order:

Paths below are the hybrid `agent/` layout scaffolded into every project folder (`clients/<ClientName>/PROJ-<project>/agent/`) — see [`agent/schema.md`](../../../agent/schema.md).

1. **Client profile** — `clients/<ClientName>/CLIENT_PROFILE.md`
2. **Project context** — `clients/<ClientName>/PROJ-<project>/PROJECT_CONTEXT.md`
3. **Discovery digests** — `<project>/agent/wiki/digests/` (all files) — processed summaries of transcripts and client artifacts
4. **Solutioning artifacts** — `<project>/agent/work/design/` and `<project>/agent/work/specs/` (existing files)
5. **Raw meeting notes** — `<project>/agent/raw/transcripts/` and `<project>/agent/raw/discovery/` — read these even if a digest exists; digests may not capture specific system pain points

If none of these exist, ask the user:
> "I don't see any ingested discovery artifacts. Do you have an RFP, statement of work, meeting notes, or existing demo scenario I should read first?"

### Pain-to-Demo-Moment Mapping (mandatory before drafting)

Before drafting, build an internal checklist of every named client pain point and verify each one maps to a demo segment:

- **Primary source:** the "System Pain Points / Limitations Raised" section in transcript digests, or "Current-State Pain Points or Gaps" in discovery artifact digests — these sections are structured for exactly this purpose
- **Fallback:** if no digest exists yet, or the digest predates these sections, read the raw meeting notes or source artifact directly
- For each pain, identify which demo segment will address it and how
- Flag any pain with no corresponding demo moment — add it to the demo or explicitly name it as future design

This check is what prevents the demo from being a capability tour that misses what the client actually came to see addressed. If digests have the pain points section populated, this step is fast. If they don't, reading raw notes is the fallback — not the default.

---

## Step 2: Determine Demo Scenario

Before drafting, confirm the following are clear from context (ask if not):

| Element | Source |
|---------|--------|
| **Demo customer** (fictional end-customer) | Discovery or ask user |
| **Core problem / incident** | Discovery or ask user |
| **SLA / contract tier** | Discovery or ask user |
| **Duration target** | Ask user (default: 90–120 min) |
| **Audience** | Ask user (default: Business Stakeholders) |
| **Primary app** (model-driven app the demo runs in) | CLAUDE.md / discovery — **if unknown, ask**; if it needs a new app, document it |
| **Demo date & time** (the actual slot) | **Ask user** — needed to anchor SLA timers, "days in stage", past-due/trajectory data |
| **RFP sections** (if applicable) | Discovery artifacts |
| **Key capabilities to show** | Discovery + PROJECT_CONTEXT |

> **Primary app & forms (pin before drafting).** Every clickpath/master-script link resolves against one
> model-driven app (its `appid`) and a specific form. Confirm the **primary app** — if it isn't clear from
> context, **ask**; if the demo needs an app that doesn't exist yet, **document the new app** as a build item
> rather than assuming an OOB one. When a beat opens a record, **default to the table's first main form** unless a
> beat needs a specific one (some controls — e.g. SLA KPI timers — only render on certain forms); when unsure,
> **ask or verify against the build, then name the form** in the beat's setup note. Details:
> [references/demo-data-fidelity.md](references/demo-data-fidelity.md) §6.
>
> **Demo date/time.** Capture the real slot and anchor all time-relative data to it (re-anchor if it moves) —
> see §2 and §8 of the fidelity reference.

---

## Step 3: Determine What to Generate

Ask if not already clear:

> "Do you want me to generate the **Demo Outline** (high-level), the **Presenter Clickpath** (deep reference), the **Demo Master Script** (present-from), or a combination? For a live client demo, the usual set is all three."

| Choice | Output file |
|--------|-------------|
| Demo Outline | `clients/<ClientName>/PROJ-<project>/04_solutioning/DemoOutline.md` |
| Presenter Clickpath | `clients/<ClientName>/PROJ-<project>/04_solutioning/Presenter_Clickpath.md` |
| Demo Master Script | `clients/<ClientName>/PROJ-<project>/04_solutioning/Demo_Master_Script.md` |

Always name the files `DemoOutline.md`, `Presenter_Clickpath.md`, and `Demo_Master_Script.md` — not date-stamped or versioned. These are the living source-of-truth files.

> **When to produce the Master Script:** for any **live-presented** demo, especially with a hard time ceiling or
> multiple acts/personas/tabs. For a short single-thread internal walkthrough, Outline + Clickpath are enough.
> Don't leave parallel `_MR` / `_DRAFT` / `_CONSOLIDATED` variants — consolidate them **into** the Master Script
> and **archive** the rest (fidelity reference §5).

> **Note on folder structure:** `04_solutioning/` has three tiers:
> - Root: `DemoOutline.md`, `Presenter_Clickpath.md`, `Demo_Master_Script.md` (presenter-facing, always at root)
> - `specs/`: technical build specs for developers (`Demo_Build_Spec.md`)
> - `archive/`: superseded versions of any of the above

---

## Step 4: Generate Demo Outline

The Demo Outline is a 1–2 page summary. Format:

```
[Demo Title] ([duration])
Scenario
[1-paragraph scenario: who is the customer, what broke, what SLA applies]

[Part N]. [Part Name] ([duration])
• [Capability bullet 1]
• [Capability bullet 2]
...

Key Messages
• [Message 1]
• [Message 2]
...
```

**Rules:**
- Each part maps to a logical demo phase (Intake, Manage, Deliver, Close, Analyze, etc.)
- Timings should sum to total demo duration
- Capability bullets use noun phrases, not verbs ("AI-assisted case creation", not "Show AI case creation")
- Key messages are 4–6 items: the top reasons the client should choose the solution

---

## Step 5: Generate Presenter Clickpath

The Presenter Clickpath is the full script. Format:

```
[DEMO TITLE] - PRESENTER GUIDE
Duration: [X] minutes | Audience: [Audience]

DEMO SCENARIO
Customer: [Fictional customer name + tier]
Issue: [Asset ID / incident description]
SLA: [Response / resolution requirements]

[PART N]: [PART NAME] ([total time])
RFP: [RFP section numbers if applicable]

[N.n] [Section Name] ([time])
SHOW: [Screen / feature to navigate to]
CLICK THROUGH: [Numbered steps — specific clicks, what appears]
SAY: "[Exact talking point in quotes]"
```

**Rules for Clickpath:**
- Every subsection has SHOW, CLICK THROUGH, and SAY
- CLICK THROUGH uses numbered steps; nested bullets for what appears on screen
- SAY lines are short, punchy, one to three sentences — in quotes
- Mark optional/cuttable sections with `[Can shorten]` or `[Can cut]`
- Include a TIMING GUIDE table at the end
- Include KEY MESSAGES section at the end (numbered, 8–10 items)
- Include Q&A section: BE READY FOR + HAVE READY
- Include RECOVERY MOVES section: common failure scenarios and exact recovery language
- Include RECORD QUICK REFERENCE section for any demo with pre-seeded data: lists all named records, accounts, work order numbers, and resources used in the click path

**Honest guardrails rule:** Where a capability requires a separate license, a future implementation phase, or is being shown as illustrative rather than live, the SAY line must name that honestly. Do not let the presenter claim full live capability for something that is mocked, unlicensed, or not yet built. The clickpath should include explicit license caveat notes (e.g., "this notification flow uses Power Automate — included with Field Service; full journey orchestration requires D365 Customer Journeys, a separate license") wherever the boundary matters to a buyer.

### TIMING GUIDE format

```
TIMING GUIDE
Section          Time    Flexible?
[Part name]      X min   [No / Cut Y (save Z min)]
...
TOTAL            X min   Can cut to Y min
Target: [X] minutes with flexibility
```

### KEY MESSAGES format

```
KEY MESSAGES (Reinforce Throughout)
1. [Theme] - [One-line explanation]
2. ...
```

---

## Step 5b: Generate Demo Master Script (live demos)

For a live-presented demo, generate the **Demo Master Script** — the present-from document that interleaves the
run-of-show with the word-for-word clickpath as **SAY + CLICK choreography**. The Outline stays the internal
briefing; the Clickpath becomes the **deep reference**; the Master Script is what the presenter drives from.

Follow [references/master-script-template.md](references/master-script-template.md) for the full structure. The
required pieces:

- **Header** — what the doc is, the hard ceiling + target, Presenter · Environment · Author · Updated, and a
  pointer to `Presenter_Clickpath.md` as the deep reference.
- **Legend** — the SAY / CLICK / TYPE / DO / AND / THEN tokens plus ⭐ LIVE, 🔒 KEEP, ✂️ CUT, ⚙ Setup markers.
- **Tab / app pre-load map** — lettered tabs/apps to open before go-time, each with its persona/login; built on
  the **primary app** pinned at Step 2. Note the minimum set for the time-boxed run.
- **Timing table** with **cut + restore order** and never-cut/fixed callouts.
- **"Decisions this script reflects"** — reconciles the script to the resolved decision log and latest build;
  names the canonical numbers/personas once.
- **Acts** — numbered beats with interleaved choreography; ✂️ CUT beats collapsed with a bridge line + restore
  note; ⚙ Setup notes ride inside the beat they gate and **cite the SOP** for any build mechanic
  (SLA-timer re-anchor, pricing refresh, portal cache, demo-record stamp).

**Cross-artifact consistency:** part names, timings, persona names, and headline numbers must match the Outline
and Clickpath verbatim. After writing, **grep for stale tokens** across all three (fidelity reference §5).

---

## Step 5c: Demo data review (subgrids, date/time, demo-record stamping)

Before handing off to the build (Step 7) — or when reviewing existing demo data — do a fidelity pass on the
**required records** for each beat. This skill does not seed data; it **specifies** what the data skills must build.

1. **Subgrid validation.** For each record a beat opens, read the **subgrids and related tabs on its primary form**
   and decide which related rows the story needs populated (quote feedback, open invoices, corrective-action
   tasks, etc.). An empty subgrid the presenter scrolls past reads as demoware. Seed only what advances the beat
   (beat-value test). See [references/demo-data-fidelity.md](references/demo-data-fidelity.md) §7.
2. **Date/time anchoring.** Anchor every time-relative element (SLA timers, days-in-stage, past-due, trajectory)
   to the demo date/time captured at Step 2; record the assumption in the Master Script's setup notes (§2, §8).
3. **Demo-owned record stamping.** If the project's `CLAUDE.md` records the CE environment **purpose as a demo
   environment**, require the two hidden stamp fields — `hso_demouse_text` (ties the record to a specific
   demo/client) and `hso_demodate_date` — on every record the demo uses, so a parallel build can't overwrite the
   seeded data. Creating/hiding the fields is a data/config task; this skill **requires the stamp in the build
   spec** and confirms it's set on the records the Master Script depends on (§8).

---

## Step 6: Save and Report

Save files to `clients/<ClientName>/PROJ-<project>/04_solutioning/`.

Report back:
- What was generated and where
- Key assumptions made (fictional customer name, SLA values, any capability coverage gaps)
- Any RFP sections that couldn't be mapped to a demo flow (gaps to call out)

---

## Step 6b: Contribute to Solution Scope

If the opportunity has a consulting `PROJECT_CONTEXT.md`, add each Microsoft product/module the demo showcases (the D365 apps, Finance & Operations, Power Pages, Fabric, etc.) to its **Solution Scope** table as a `recommended` row, per the [Solution Scope Contribution Protocol](../../../agent/wiki/sop/presales/solution-scope-contribution.md). Match by product name (one row each); advance status, never downgrade. Skip in a delivery repo (no `PROJECT_CONTEXT.md`).

## Step 7: Offer Build Spec

After generating the clickpath, always offer:

> "The Presenter Clickpath is done. Do you want me to generate a **Demo Build Spec** that maps each clickpath segment to the specific D365 configuration, data, and custom development needed to support it?"

If yes, invoke `hso-dataverse-architect` in **Demo Build Spec** mode:
- Input: the completed `Presenter_Clickpath.md` + all discovery digests
- Output: `clients/<ClientName>/PROJ-<project>/04_solutioning/specs/Demo_Build_Spec.md`
- See [references/demo-build-spec-template.md](references/demo-build-spec-template.md) for the expected structure

The build spec is developer-facing; the clickpath and outline are presenter-facing. They are complementary but separate documents for separate audiences.

**Demo ≠ decided shape.** A demo answers "can the platform do this?" for a pain point; it does not decide the engagement's solution shape. When the deal moves from demo toward estimate, the shape is decided in `hso-dataverse-solution-map` (Presales Playbook Stage 3 — Shape); a demo moment is a valid **prototype** ticket asset there, and the demo's Solution Scope contributions (Step 6b) enter that map as `recommended` rows, not as decisions.

---

## Quality Standards

Every Presenter Clickpath must:
- Have specific, navigable CLICK THROUGH steps (not "show the dashboard" — show which dashboard, which fields appear)
- Reference real capability names from the platform (e.g., "RSO optimization", "Field Service Mobile", "Copilot in Power BI")
- Map visible demo steps back to client requirements (RFP section, stated pain point, or discovery finding)
- Be presentable end-to-end without the presenter needing to improvise structure

Every Demo Outline must:
- Fit on 1–2 pages
- Be usable as a standalone internal briefing document
- Align part names and timings with the Presenter Clickpath (they describe the same demo)

---

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
