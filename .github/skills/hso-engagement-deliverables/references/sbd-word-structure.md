# Solution Blueprint Document (SBD) — Word structure & recipe

The **SBD** is the written HSO Solution Blueprint (Word), distinct from the Solution Blueprint *Presentation*
(PPTX). It follows a **fixed HSO skeleton** on the HSO Word style family. Apply the standards in
[HSO Client Deliverable Standards](../../../agent/wiki/sop/client-deliverables/hso-client-deliverable-standards.md)
§4–§6a — this file is the *how*. Generic only: **no client content or names live here or in the skill.**

> **Base:** by default the builder uses the **bundled zero-config HSO donor** (`assets/HSO_Word_base.docx` —
> sanitized from the Global HSO Word Template: empty body, Segoe UI theme, stock styles). Override with an
> accepted SBD donor / legacy template via `CLAUDE.local.md` → Branding Resources (`Local SBD Sample Path` /
> `Local Word Template Path`). **Format only — empty the body and rebuild the skeleton; never carry the donor's
> client text, names, or logos** (SOP §6a).

## Style family (resolve by name, with fallback)

Two style vintages exist; the resolver (`S(name, fallback)`) handles both — **never hard-code font/size:**

- **Current (bundled donor / Global HSO template):** stock **`Heading 1/2/3/4`** (auto-numbered decimal),
  **`Title`**, **`Subtitle`**, **`List Paragraph`**, **`Table Grid`**, **`TOC Heading`**, all branded via the
  **Segoe UI theme**. No `List Bullet` style — bullets fall back to `List Paragraph`.
- **Legacy (older HSO SBD donor, e.g. a pre-2026 doc):** the custom `HSO …` / `AKA …` family below. Still
  honored when a donor carries it.

Primary → fallback the resolver applies:

| Role | HSO SBD style | Fallback |
|------|---------------|----------|
| Report title | `AKA Title of Report` | `Title` |
| Subtitle | `AKA Subtitle of Report` | `Subtitle` |
| Prepared for / by | `AKA Prepared for` / `AKA Prepared by` (+ `… name`) | `Normal` (kv table) |
| 1st/2nd/3rd/4th-level heading | `HSO 1st/2nd/3rd/4th Level Heading` (auto-numbered decimal) | `Heading 1/2/3/4` |
| Body | `HSO Body` | `Normal` |
| Bullets L1/L2/L3 | `HSO Bullets - Level 1/2/3` | `List Bullet` |
| Front-matter section head | `HSO Bold Blue Heading - 2` / `HSO Blue Heading - 1` | `Heading 1` |
| Table heading | `HSO Table Heading` / `Table Heading` | bold run in `Table Grid` header |
| Tables | `Table Grid` / `AKA Table` | `Table Grid` |

Headings are **auto-numbered by the style** — never type the number into the text (SOP §4; see
[word-deliverable.md](word-deliverable.md) §5 for the numbering-injection fallback when a plain donor's
`Heading n` does not auto-number).

## Front matter (before the TOC)

Reproduce these section headings; fill each with HSO's standard boilerplate or `[PLACEHOLDER: …]`:

- **Copyright**, **Trademarks**, **Disclaimer** — HSO standard boilerplate (from the donor's own text if the
  user confirms it is generic HSO boilerplate, else `[PLACEHOLDER: HSO standard <section> text]`).
- **Contributors** — a `Name | Role | Company` table (see below).
- **Revision History** — a `Version | Section | Content Change | Date` table (see below).
- **Table of Contents** — an auto-updating TOC field, levels 1–3 (recipe: [word-deliverable.md](word-deliverable.md) §6).

## Body skeleton (generalized)

Auto-numbered `HSO n Level Heading`. 2nd/3rd-level items are the **HSO defaults**; keep those in scope and drop
the rest, or add project-specific ones. Every leaf gets project content or `[PLACEHOLDER: …]`.

| # | 1st level | Typical 2nd level |
|---|-----------|-------------------|
| 1 | Introduction | — |
| 2 | Solution Blueprint Document Purpose | — |
| 3 | Solution Overview | System Landscape · System Integrations/Interfaces · Solution Extensions |
| 4 | System Architecture & Technical Considerations | Users and Licensing · Security · Data Management · Document Management · Interface Design Patterns · Mobile · Power Platform apps and services · Printing |
| 5 | Global / Cross-Area Configurations | (project-driven; e.g. Financial Structure · Number Sequences · Addresses · Configuration Keys · Intercompany · Approval Workflows · Units of Measure · Other) |
| 6 | Business Solution | **one 2nd-level heading per in-scope area** — sub-headings = the area's processes |
| 7 | Acceptance | — |

**Section 6 is where scope drives structure.** Emit a 2nd-level heading only for **in-scope** solution areas;
under each, a 3rd-level heading per in-scope process. Do **not** paste the full D365 F&O module catalog
(FIN/PDM/PUR/LOG/PRJ/HRM/SLS/…) — that is one optional variant, used only when the engagement is D365 F&O and
the user asks for the full catalog.

## A. Per-section content & sourcing (system-scoped)

**§6 is not the only scope-driven section — §3–§6 all are.** Which D365 systems (**Finance & Operations** vs
**Customer Engagement**), their modules/apps, and their integrations are in scope determines what each of those
sections contains. Resolve the in-scope systems *before* populating sections; the resolution process (read
documented scope → confirm → if undocumented, confirm-where-it-belongs and ask) is the shared step in SOP §4a and
`SKILL.md` Workflow step 2. This section is the **content map** those steps feed.

### A.1 System-scope taxonomy (what to resolve / ask for)

- **F&O** — Finance (GL/AP/AR) · Supply Chain Management · Manufacturing · Project Management & Accounting · HR · Commerce.
- **CE** — Sales · Customer Service · Field Service · Project Operations · Customer Insights (Marketing).
- **Power Platform** — Power Apps (model-driven / canvas) · Power Automate · Power Pages · Power BI.
- **Integrations** — Dual-write · Data Integrator · virtual tables · Azure (Service Bus / Functions / APIM) · M365 (Exchange / SharePoint DMI / Teams) · external / ERP / edge.

### A.2 Per-section content-type & sourcing matrix

Emit a §3–§6 sub-section **only** for an in-scope system/module/integration; everything sourced-but-incomplete
gets a highlighted `[PLACEHOLDER: …]`; out-of-scope items are omitted, not placeholdered.

| # | Section | Content **type** | **Where to pull** | How **in-scope systems** drive it |
|---|---|---|---|---|
| 1 | Introduction | short prose | charter · `PROJECT_CONTEXT.md` · discovery digests | names the systems / scope at a high level |
| 2 | SBD Purpose | boilerplate prose | HSO standard + engagement scope | states which systems the blueprint covers |
| 3 | Solution Overview → System Landscape | landscape **diagram** + prose | `agent/wiki/system/` env map; `../scripts/Build-ArchitectureDiagram.py` | one node per in-scope app (F&O, CE, PP, external) + relationships |
| 3 | → Integrations / Interfaces | **table** (source→target · pattern · direction) | `agent/wiki/system/`; integration design; dual-write / azure-integration SOP | one row per in-scope integration |
| 3 | → Solution Extensions | list / table | `work/specs/` · `work/build/` · solution components | custom PCF / plugins / flows grouped by app |
| 4 | Sys Architecture → Users & Licensing | license **table** | licensing SOP · `ip-in-use.md` · user counts | **F&O user/activity vs CE per-app** license models — list per system |
| 4 | → Security | prose + role **matrix** | security design; `hso-dataverse-securityrole` matrix | **F&O duties/privileges** vs **CE roles / BUs / teams** |
| 4 | → Data Management | prose + tables | data model; data-migration / MDM SOP | F&O entities vs Dataverse tables; ownership, MDM, retention |
| 4 | → Document Management | prose | SharePoint-integration SOP | CE SharePoint DMI vs F&O document handling |
| 4 | → Interface Design Patterns | patterns list | azure-integration / dual-write SOP | sync vs async; pattern per interface |
| 4 | → Mobile | prose | mobile-and-offline SOP; FS-mobile | **FS Mobile (CE)** vs **F&O mobile workspaces** |
| 4 | → Power Platform apps & services | list | `ip-in-use.md` · `work/specs/` | which PP components are in scope |
| 4 | → Printing | prose | reporting design | **F&O SSRS / Electronic Reporting** vs **CE Word templates / DocMix** |
| 5 | Global / Cross-Area Configurations | config **tables** | configuration-data SOP; design | **F&O-heavy** (legal entities · number sequences · financial dimensions · config keys · intercompany) vs **CE** (BUs · autonumber · currencies) |
| 6 | Business Solution → per in-scope area | 2nd-level per area; 3rd-level per **process** | `work/specs/` · BPFs · process digests · ADO features | **each in-scope F&O module and CE app becomes a 2nd-level area**; its processes are sub-headings |
| 7 | Acceptance | sign-off **table** | engagement terms | acceptance criteria per system / phase |

Before issuing, run the pre-issue QA checklist [`sbd-qa-checklist.md`](sbd-qa-checklist.md).

## Contributors & Revision History (attribution — SOP §5)

There is **no single stamped author.** Never default a name from `CLAUDE.local.md` into either table.

```
Contributors        -> table(["Name","Role","Company"],
                              [["[PLACEHOLDER: name]","[PLACEHOLDER: role]","HSO"]])
Revision History    -> table(["Version","Section","Content Change","Date"],
                              [["1.0","All","Initial Release","<date>"], ["","","",""]])
```

Use only names the user explicitly supplies for *this* document; Company defaults to `HSO`. Leave the docx
**core author metadata blank** (or `HSO`).

## Build

`scripts/Build-WordDeliverable.py` drives this from a JSON spec. For an SBD, set `"sbd": true` (emits the
skeleton above with `[PLACEHOLDER: …]` leaves you then overwrite via `blocks`), supply `contributors` and
`revision_history` instead of the retired `change_record`, and point `base` at the donor. See
[word-deliverable.md](word-deliverable.md) for the full spec, gotchas, and the `.dotx`/donor decision.
