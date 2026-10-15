---
name: hso-learning-pack
layer: atomic
scope: core
description: >-
  Build a multi-audience learning pack — landing site, audience decks (HTML + PPTX), feature library, pillar overviews, screen/walkthrough library, master PDF — for one of three content types chosen in Step 0 — a model-driven Dataverse / D365 app (grounded in the solution export + shared/dv wiki), internal enablement (an AI-agent/skills + SOP + methodology accelerator such as Forge USA), or other (SDK, CLI/framework, methodology body). Use whenever the user wants to onboard people to a product, train consultants or end users, document an app or accelerator, "wow stakeholders", productize internal IP, build engagement training material, OR update an existing pack — even if they don't say "learning pack". Tailors pillars, audiences, primer, and screen library to the content type; works with or without a live UI to capture.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch, Skill, AskUserQuestion
---

# Model-Driven App Learning Pack Builder

Build a polished, multi-audience learning website. **What you are documenting is chosen in Step 0** — the pack's machinery (pages, decks, PDF, deploy) is identical across all three content types; what changes is where the content is *grounded* and four specific shape decisions. The end-state is roughly:

- **Landing page** with a "Pick your role" card grid + primer + quick-launch links
- **Primer** — the context a reader needs before the rest lands. For a model-driven app: the *industry/business* it serves plus a short *"what a model-driven app is"* explainer. For internal enablement: the *paradigm* — how agent-assisted delivery actually works (see Step 0)
- **Audience decks** — tailored to who actually uses the thing, not a fixed list. The app default is executive, sales, functional consultant, technical/solution architect, enterprise architect, project manager, plus a one-page exec brief in Word; other content types swap in their own roles (see Step 0). Each in both HTML (slides) and PPTX
- **Feature library** — narrative guides per major capability, prev/next navigable. A "feature" is a business capability the app delivers (a subscription lifecycle, a payment flow) — or, for internal enablement, a skill, an SOP family, or a toolkit capability
- **Pillar overview pages** — one card-grid page per top-level area
- **Screen library** — one walkthrough page per captured surface. For a model-driven app: a record form, a saved view / grid, a dashboard, a BPF stage, or a custom page; with no environment to capture, **data-model + architecture diagrams** plus layout descriptions read from the solution XML. For internal enablement and most "other" types: **annotated tool-session walkthroughs** (editor / CLI / portal) — see Step 0
- **Master PDF** — the whole pack flattened into one ~500-page distillation for AI ingestion / instructor-led course generation
- **Deploy scripts** — Azure Static Web Apps with optional Entra ID auth, publish date auto-stamped at deploy

The skill is fully self-contained. Every script, theme, template, and worked example you need ships inside this skill folder. When you reach for "what does a good X look like," read the bundled `templates/*.reference` files — they are the canonical look-and-feel, and they are **content-type-neutral**: the same templates serve all three types.

## When to invoke

The user said something like:

- "Build a learning pack for [the X app / the Y solution]"
- "Document this model-driven app / this Dataverse solution top-to-bottom"
- "I want to wow stakeholders with documentation for [X]"
- "Build training material for the [engagement] app"
- "Productize this solution's docs" / "Create an onboarding site for [X]"

Don't invoke for: standalone PowerPoint decks (use `hso-revealjs-presentation` or `presentation-builder`), a single solution-component reference doc (use `hso-solution-documentation` / `hso-update-solution-docs`), a feature spec / FDD (use `hso-dataverse-architect`), or a flow-documentation pass (use `hso-dataverse-flow-docs`). This skill is the *multi-audience learning pack* — it consumes those narrower artifacts as source.

## Step 0 — Ask what kind of content this pack documents (do this first)

**Do not skip this and do not guess.** Every downstream default in this skill — the primer, the pillars, the audience set, the screen library — is shaped by the answer, and forcing the wrong shape onto a pack is the most common way this skill produces something awkward (a "screen library" with no screens, an "industry primer" for something that serves no industry, audience decks for roles that don't exist).

Use `AskUserQuestion` to put the choice to the user explicitly:

> **What kind of content is this learning pack documenting?**
>
> | Option | What it means | Grounded in |
> |---|---|---|
> | **Model-driven app** | A Dataverse / Dynamics 365 app — real users sign into a Power Apps app whose UI (sitemap → tables → forms, views, dashboards, BPFs) is generated from a solution | The exported solution + the shared/dv model-driven-apps wiki |
> | **Internal enablement** | An AI-agent / skills + SOP + methodology accelerator that a team uses to *deliver* work — **Forge USA itself is exactly this**. The real IP is the standards/knowledge layer, and the audience is mixed-skill practitioners, not end users | The skills catalog, the SOP corpus, the ADR set, the wiki |
> | **Other** | A developer SDK/toolkit, a CLI/framework/platform, a standalone methodology or best-practices body, or a deployed app that is *not* model-driven | The source repo, read via parallel subagents |

If the user already made the content type obvious ("build a learning pack for this Dataverse solution", "document the Forge accelerator"), confirm it in one line rather than interrogating them — but still state which type you're proceeding as, so a wrong inference is cheap to correct.

### What the answer changes

The workflow below runs as written for all three. The content type overrides the defaults at exactly **five** points:

| Point | Model-driven app | Internal enablement | Other |
|---|---|---|---|
| **Grounding** (below) | Solution export + shared/dv wiki + `hso-dataverse-*` skills for live metadata | Skills catalog + SOP corpus + ADRs; cite the SOP, never invent the standard | Source repo via parallel subagents |
| **Pillars** (Phase 1) | Sitemap Areas → Groups → SubAreas | Capability bands (discovery, build, ALM, governance) or the skill-layer taxonomy | Top-level product areas |
| **Audiences** (Phase 2) | Who uses the app — the 7-role default | Practitioner seats (functional, technical, presales, practice lead) + a "de-intimidation" track for low-code readers | Whoever consumes the product |
| **Primer** (Phase 3) | The industry/business + "what a model-driven app is" | The *paradigm* — how agent-assisted delivery works, why the wiki/SOP/skill split exists | The product's working model |
| **Screens** (Phase 4) | Forms, views, dashboards, BPF stages, custom pages | Annotated tool-session walkthroughs (editor / CLI / portal) | Tool sessions or diagrams |

**For "internal enablement" and "other", read [`references/non-app-archetypes.md`](references/non-app-archetypes.md) before Phase 1.** It carries the detailed adaptations for those four shape points plus a worked example of the Forge USA accelerator pack. For a model-driven app you won't need it.

### If the answer is "model-driven app" — find the app and name its parts

Locate, in the source repo (and confirm live with the `hso-dataverse-*` skills if an environment is reachable):

1. **The solution export** — usually under `Solutions/<SolutionName>/`. This is the read-only source of truth for the app's structure.
2. **The model-driven app module(s)** — `Solutions/<S>/AppModules/<app_uniquename>/AppModule.xml`. Note the unique name, display name, and description. One solution can ship more than one app, and the app's display name may differ from the solution name — document the *app* the users actually open. (Example: a `HSOBillingPlatform` solution may surface through an `hso_HSOFieldService` / "HSO Field Service" app.)
3. **The sitemap** — `Solutions/<S>/AppModuleSiteMaps/<app>/AppModuleSiteMap.xml`. Its **Areas → Groups → SubAreas** are the app's navigation, and the strongest candidate for your pillars (see "Picking pillars").
4. **The tables** — `Solutions/<S>/Entities/<Entity>/Entity.xml` plus each table's `Forms/`, `SavedQueries/` (views), and attributes. These define what a learner sees and edits.
5. **Dashboards, business process flows, custom pages, charts** — also solution components; each is a documentable surface.
6. **The code + automation** — plugin source (`SourceCode/`), registered SDK steps (`Solutions/<S>/SdkMessageProcessingSteps/`), Power Automate flows (`Workflows/`), web resources, and integrations. These back the *features*.
7. **The sample data** — `SampleData/` manifests and CSVs reveal the real entity set, relationships, and the demo story the app tells.

If, on inspection, the thing turns out **not** to be a model-driven app after all, go back to the Step 0 table and re-pick — the shape decisions above will fight you otherwise.

**Updating an existing pack.** This skill is also the tool for *iterating* on a pack you (or it) already built. Don't regenerate from scratch: feature/pillar pages come from `feature-metadata.json` via `scripts/generate-feature-guides.py` (edit the JSON, re-run), decks are re-rendered per file, and a new standalone narrative page is one markdown file + a render pass. Match the existing voice, re-render only what changed, and re-run the link/leftover checks.

## Grounding

Whatever the content type, the rule is the same and it is the thing that separates an accurate pack from a plausible-sounding one: **every claim traces to a source you actually read.** What differs is which sources.

### If the content type is "internal enablement"

The IP is the standards layer, so ground in it directly and cite it the way HSO does:

- **The skills catalog** (`claude-code/skills/`) — `INDEX.md` is generated from frontmatter and drift-guarded, so it is the only trustworthy source for counts and the layer taxonomy. Never hand-count skills into a pack page; they go stale within weeks.
- **The SOP corpus** (`agent/wiki/sop/`) — the methodology. When a pack page makes a methodology claim, it is drawing on an SOP: link it. State the guidance, never invent the standard.
- **The ADR set** (`agent/wiki/decisions/`) — the *why* behind anything a reader will find surprising. An enablement pack that explains a rule without its ADR reads as arbitrary.
- **The wiki topics** — vocabulary and navigation.

Two failure modes specific to this type. First, **hardcoded counts** — "N skills, M SOPs" ages badly; prefer pointing at `INDEX.md`, and if you must state a number, date it and say it moves. Second, **describing the tooling as it was rather than as it is** — check the ADRs for anything superseded before you describe a workflow.

### If the content type is "other"

Ground in the source repo, read via parallel subagents (Phase 1). The product's own README, its public docs, and its code are the truth; the wiki below does not apply.

### If the content type is "model-driven app" — ground in the solution and the shared/dv wiki

Two source layers, and you need both:

- **The app itself** (project tier) — the solution XML, metadata, plugin code, flows, and sample data listed in Step 0. This is *what this app does*. Every feature claim must trace to a real table / form / plugin / flow here.
- **The product wiki** (`shared/dv/agent/wiki/`) — *what model-driven apps are, and how HSO builds them well*. This is where you get the vocabulary and the "why" for a reader who has never seen a model-driven app. Read, on demand:
  - [`topics/model-driven-apps.md`](../../../shared/dv/agent/wiki/topics/model-driven-apps.md) — the topic anchor: app strategy, sitemap, custom pages, command bar, theme, mobile/offline, app ALM, the Microsoft Learn links, and the related topics (forms/views, dashboards, security, solutions).
  - The SOPs under `shared/dv/agent/wiki/sop/model-driven-apps/` — app-module, form, view, and dashboard configuration best practices. Use these to *explain* a surface correctly (what a form tab is for, why a view is curated, what a dashboard cell does) without inventing.
  - Peer topics as needed: `topics/form-and-view-configuration.md`, `topics/dashboards.md`, `topics/security.md`, `topics/dataverse-solutions.md`, `topics/power-automate.md`, `topics/plugin-development.md`.

When you need *live* metadata the export doesn't make obvious (option-set values, relationship names, which forms are active, a view's FetchXML), use the `hso-dataverse-*` skills rather than guessing — see [`references/dataverse-mda-discovery.md`](references/dataverse-mda-discovery.md). **Do not invoke Dataverse MCP tools in HSO repos; use the skills.** Route skill calls through `powershell.exe` (each skill has its own token cache).

Cite the wiki the way the rest of HSO does: when a learning-pack page makes a *methodology* claim ("forms should keep the first tab light for load performance"), it's drawing on a wiki SOP — link it. When it makes an *app* claim ("the Billing Event form has a Collections tab"), it's drawing on the solution XML — that's the app's own truth.

> **If the pack will reach client/app end-users, not just an HSO-internal audience:** the wiki links above are for an internal pack. Use the SOP methodology to *explain a surface correctly*, but do not surface SOP/skill paths, `agent/wiki/` references, or HSO Override rationale in the rendered pages a client sees — those are HSO IP. State the guidance, not where it came from. See `hso-client-deliverable-standards.md` §7 "What may not leave the building".

## Workflow

Phases are sequential but each one can be iterated. **Don't try to do everything in one shot** — checkpoint with the user between phases so they can redirect.

### Phase 1 — Discovery

Goal: enough understanding of the **app and its solution** that you can name the major pillars (the app's top-level areas), the key features within each, and the surfaces (forms, views, dashboards, BPF stages) worth capturing — **with every claim backed by the solution XML, metadata, plugin code, or sample data, not just by docs.**

**Phase 1 is not a 30-second job.** If it finished fast, you didn't do it — you read a spec and stopped. A real Phase 1 takes 10–30 minutes (with parallel subagents) and produces a written inventory grounded in actual solution paths and logical names. Skipping the solution-traversal step is the #1 source of inaccurate downstream content: it's how you end up writing a guide about a "feature" that is really one option-set value, or describing a form tab that doesn't exist, or mislabeling a plugin's job.

The detailed how-to — where each component lives in the export, what to read, and which `hso-dataverse-*` skill to use for live metadata — is in [`references/dataverse-mda-discovery.md`](references/dataverse-mda-discovery.md). Read it before Step 2. The steps below are the spine.

#### Step 1 — Catalog what already exists in writing

*Hypotheses* about the app, not ground truth. Read them, then verify against the solution in Step 2.

1. `CLAUDE.md` at repo root — project config (publisher prefix, default solution, environment URL).
2. The project's `agent/` wiki — `agent/index.md`, topic anchors, digests, any feature spec or FDD under `agent/raw/discovery/` or `agent/work/specs/`. These are the richest narrative source for *why* the app exists.
3. Any `Solutions/.docs/<Solution>/<Solution>.md` — generated solution documentation (from `hso-solution-documentation`).
4. README / SPEC / PROGRESS docs; recent `git log` — what's actively shipping.
5. The **shared/dv wiki** for the *generic* model-driven-app concepts you'll need to explain (see "Grounding in the shared/dv wiki").

For each claim ("the app supports X", "feature Y handles Z", "we integrate with W"), **write it down to verify in Step 2.** Note where docs disagree or go vague.

#### Step 2 — Verify every claim against the solution and code

This is the heart of Phase 1. **Spawn 4–6 `Explore` subagents in parallel**, one per candidate pillar (a sitemap Area or a functional table group). (Harness note: the parallel fan-out is an optimization, not a contract — on a harness without subagent dispatch, run the same per-pillar briefs sequentially in-session; the verification bar is unchanged.) Brief each with the same template:

> "Audit the `<pillar>` area of the `<solution>` solution under `Solutions/<S>/`. Inventory, with a file path or logical name for each: (1) the **tables** in this area — logical name, display name, one-line purpose, from `Entities/<E>/Entity.xml`; (2) the **forms** per table (`Forms/`) — tabs and the columns/subgrids they show; (3) the **views** (`SavedQueries/`) surfaced in the sitemap; (4) **dashboards / charts / BPFs / custom pages** in scope; (5) the **plugins / SDK steps** (`SdkMessageProcessingSteps/`, `SourceCode/`) and **Power Automate flows** (`Workflows/`) that automate this area, and what business rule each enforces; (6) **integrations** (gateway adapters, ERP sync, webhooks) touching this area. Don't speculate — quote the XML / code."

The output is your **solution-anchored feature inventory**: every claim traces to a real component.

#### Step 3 — Read the load-bearing components yourself

Subagents give breadth; you read the load-bearing pieces yourself for depth:

- **Core table `Entity.xml` + attributes.** What columns does the table actually carry? Which are choice columns, and *what are the option-set values* (the values are the system's vocabulary made concrete — `CollectionStatus`, `TenderType`, `InvoicingStrategy`). Lookups reveal the relationship graph. Don't assume a schema is narrow — read it. Use `hso-dataverse-data-modeling` for live option-set values if the export is unclear.
- **The active forms.** Open the form XML (or use `hso-dataverse-ui-config` `AnalyzeForm`). The tab/section/field/subgrid layout *is* what a user sees — it's your screen-walkthrough source even before you capture a screenshot.
- **The sitemap.** `AppModuleSiteMap.xml` is the app's table of contents — it tells you which tables/dashboards are first-class (and which exist but aren't surfaced).
- **Plugin business logic.** The service classes under `SourceCode/.../BusinessLogic/Services/` name the real operations (a `RoyaltyCalculationService`, a `PaymentProcessingService`). The registered SDK steps say *when* they fire.
- **Power Automate flows + integrations.** `Workflows/*.json` and any gateway/ERP adapter projects are the external edges of the app.
- **Sample data.** The `SampleData/` manifest + CSVs are the demo story — they show the entity set, the relationships, and realistic records you'll point screenshots at later.

#### Step 4 — Cross-check docs vs. solution, write the truth

For every claim from Step 1, mark it ✓ (confirmed in the solution/code), ✗ (contradicted), or **stale** (claimed, but no component evidence). Don't let stale or contradicted claims into the pack — they burn stakeholder trust the first time someone opens the app and it doesn't match. When the spec is rich, sample-check 3–5 claims before trusting it wholesale; when the solution and a doc disagree, **the solution wins** — and surface the disagreement to the user.

#### Outputs of Phase 1

A `FEATURES.md` in the pack folder, containing:

- **3–6 pillars** (top-level app areas — see "Picking pillars"). For each: a one-paragraph narrative and the sitemap Area / table group it maps to.
- **20–30 features** grouped under pillars. For each: a 1–2 sentence pitch, the primary table(s) + form(s) + plugin/flow backing it (with logical names / paths), and the upstream/downstream features it connects to.
- **Table catalog.** Every table: logical name, display name, purpose, key choice columns and their values.
- **Integration list.** Every external system, with the adapter/flow that handles it.
- **Cross-cutting concerns.** Security roles + business-unit model, BPFs, audit, notifications, theming.
- **Open questions** — anything unconfirmed that the user must clarify before Phase 3.

**If Phase 1 finished in under 5 minutes, go back and do it.** A polished pack on a shallow Phase 1 costs far more to fix than doing it right the first time.

#### Picking pillars — logical ways to break up the app

A "pillar" is a top-level area of the app — the unit a learner can grasp in one sitting. The pack works when each pillar tells a complete sub-story. It falls flat when pillars are arbitrary buckets ("the custom tables", "the plugins") that mean nothing to a user.

Pick 3–6 pillars. Fewer than 3 and the pack feels monolithic; more than 6 and the landing-page card grid breaks and learners stop scanning.

> **For a model-driven app, the sitemap is your first and best pillar source.** Its **Areas** (and, in a single-area app, its **Groups**) are already a curated, business-meaningful decomposition the makers chose. Start from there and adjust only if an Area is too thin or too broad. The other strategies below are for when the sitemap is one flat Area or doesn't reflect the real story.
>
> **Not a model-driven app after all?** If Step 0 reclassified the product (SDK / CLI / methodology accelerator), use the lifecycle-plus-substrate decomposition in [`references/non-app-archetypes.md`](references/non-app-archetypes.md) instead.

**Decomposition strategies — pick whichever fits, in this priority order:**

1. **Sitemap Areas / Groups.** The makers' own navigation grouping. Almost always the right answer for a model-driven app — it's what users already see.
2. **Business lifecycle stages.** Best when the app shepherds something through phases (e.g. subscribe → bill → collect → reconcile, or intake → schedule → complete → invoice). Each phase a pillar. Often a cleaner story than the raw sitemap when the sitemap is alphabetical.
3. **Capability / functional table groups.** Best when the app is a set of relatively-independent capabilities (Subscriptions, Payments, Royalties, Reconciliation). Group related tables; each group a pillar.
4. **Audience / role surfaces.** Best when distinct security roles see distinct areas (collections clerk vs. finance vs. franchise admin). Watch for inventing pillars per role when they share screens.
5. **Platform / foundation layer.** Most packs benefit from one pillar for the cross-cutting plumbing: the data model, security roles + business units, integrations/gateways, ALM. Keep it last in the grid — the "how it actually works" pillar for technical audiences.

**Anti-patterns:**

- ❌ Pillars named after solution-component types (`Tables`, `Forms`, `Plugins`, `Flows`) — meaningless to a business user.
- ❌ One pillar per table when several tables tell one story (a `payment method`, `payment transaction`, and `gateway config` are one "Payments" pillar, not three).
- ❌ Mixing strategies inconsistently — pick one primary strategy and let the foundation pillar be the only exception.
- ❌ Treating standard Field Service / CE entities the app rides on as if they were the *custom* app's story — name them, but the pillars should foreground what *this* solution adds.

**Validation test:** read your 3–6 pillar names aloud as a story. "First the user does X (pillar 1), then Y (pillar 2), then Z (pillar 3) — and underneath, the platform handles W (pillar 4)." If that's incoherent, regroup.

### Phase 2 — User-supplied inputs

Goal: lock down everything you can't infer from the solution. Use **AskUserQuestion** with max 4 questions per call, grouping where possible.

Always ask:

1. **Live environment + app id.** Is the Dataverse environment reachable (the URL is usually in `CLAUDE.md`, e.g. `https://<org>.crm.dynamics.com`)? Is the app deployed *with sample data loaded* there? A model-driven app opens at `https://<org>.crm.dynamics.com/main.aspx?appid=<AppModuleId>` — the `appid` is the AppModule id from the solution. If the env is reachable and populated, we can capture the screen library (Phase 4); if not, we **defer live capture** and lean on data-model + architecture diagrams plus form-layout descriptions read from the solution XML.
2. **Authentication.** Capture uses Playwright against the live org — the user logs in interactively the first time (real browser, type creds / SSO, we save storage state). Confirm they can do an interactive login to the target environment. (Metadata reads during discovery go through the `hso-dataverse-*` skills, which use their own cached token — separate from the Playwright session.)
3. **Brand theming.** Default is HSO (Navy `#00395F`, Cyan `#079FC3`, Teal `#00B294`). User can override with their own palette. The bundled `themes/hso-theme.css` is the default; provide a swap path for `themes/<brand>-theme.css`.
4. **Business reference material + featured stakeholders.** Point us at the dossiers, transcripts, FDDs, and the project `agent/` wiki digests that explain the business the app serves — these source the primer. **Also ask which stakeholders' requested capabilities to foreground** (named people whose asks the pack should highlight): the digests/work-analysis usually record who asked for what, and surfacing "you asked for X — here it is" is the highest-impact framing for a client-facing pack.

Sometimes ask:

- **Audience list override.** Default is the 7 roles (executive, sales, functional consultant, technical/solution architect, enterprise architect, project manager, executive brief). For a Dataverse app the *end-user* roles often matter more than implementation roles — confirm whether to add an end-user / day-in-the-life track (e.g. "collections clerk", "franchise admin") mapped to the app's security roles. Confirm whether PM means "customer-implementation PM" (default) or internal.
- **Customer-specific track.** Is a specific customer/engagement the use case? If yes, plan a parallel primer track covering their industry, their business, and how the app maps to it. See `templates/customer-primer-landing.html.example`.

**Important quirks to surface:**

- If the environment is a shared config/demo org, ask which **app id** and which **data set** has the cleanest demo records — there may be more than one app installed.
- If certain forms only populate after a setup step ("a Customer Subscription only shows billing events once a plan is selected"), ask the user to walk you through the data-setup playbook for each.

### Phase 3 — Content generation (text-first)

Goal: produce the markdown source for every audience deck, every feature guide, every pillar overview, and the industry primer.

**Audience decks.** Use the `presentation-builder` skill or invoke Marp directly. Each deck is `XX-<audience>.md` (e.g., `01-executive-overview.md`).

#### Marp authoring conventions — STRICT

The HSO theme defines a small, fixed vocabulary. If the agent uses anything outside this vocabulary, Marp falls back to default styling and the decks come out looking like generic black-on-white slide decks instead of HSO-themed.

**Read these two bundled files before authoring any deck:**

1. `~/.claude/skills/hso-learning-pack/themes/marp-authoring-guide.md` — the full theme reference
2. `~/.claude/skills/hso-learning-pack/templates/01-executive-overview.md.reference` (and the other `0[1-8]-*.md.reference` files) — working examples of the entire pattern, by audience

**Required frontmatter — every deck — copy exactly:**

```markdown
---
marp: true
theme: hso-knowledge
paginate: true
size: 16:9
title: <Product Name> — <Audience Title>
---
```

**Common mistakes to avoid:**
- ❌ `theme: hso` — wrong. The CSS file declares `@theme hso-knowledge`. Anything else fails to bind and the theme doesn't apply.
- ❌ Missing the `title:` field — degrades preview rendering.
- ❌ Different `size:` value — the theme's CSS is sized to 16:9.

**The ONLY four valid slide classes:**

| Class | Use | Example |
|---|---|---|
| `cover` | Slide 1 (title) and the closing slide. **Use exactly twice per deck.** | `<!-- _class: cover -->` |
| `section` | Section divider between major themes. One `#` headline, one supporting sentence, no bullets. | `<!-- _class: section -->` |
| `stat` | Big-number slide. A `<div class="number">N</div>` element plus an `## ...` framing line. Use sparingly (1-3 per deck). | `<!-- _class: stat -->` |
| *(no class)* | Default content slide. Title + paragraphs + bullets/tables. The workhorse. | (omit the comment) |

**Common mistakes to avoid:**
- ❌ `<!-- _class: title -->` — does not exist. Use `cover`.
- ❌ `<!-- _class: section-blue -->`, `section-green`, `section-caramel`, `section-orange` — do **not** exist. The theme has no per-section color modifiers. Use plain `section`.
- ❌ Inventing new class names. If you want visual variety, vary the *content layout* (use the column patterns below) — not the class name.

**Column / card patterns** (inline HTML inside content slides):

```html
<div class="cols two">
<div class="card">

### **Card heading**
Card body. Bullets allowed.
- One
- Two

</div>
<div class="card">

### **Second card**
…

</div>
</div>
```

Also supports `<div class="cols three">` (3 cards) and `<div class="cols one">` (a single emphasized card, used for "Net: …" closing statements).

**Voice and content per audience** — adapt these from the bundled `templates/0[1-8]-*.md.reference` decks rather than improvising:



- **Executive (`01`)** — outcomes, not mechanisms. No file paths, no class names. Numbers as story tools. Each theme ends with `*Net: ...*` italic.
- **Sales (`02`)** — capability-not-feature framing. Comparison tables. One big claim per slide.
- **Functional consultant (`03`)** — implementation playbook. Process flows, workflow diagrams, decision trees. Medium technical detail.
- **Technical architect (`04`)** — `code` spans OK, full architecture stack, CQRS / framework / DB / middleware breakdowns.
- **Enterprise architect (`05`)** — integration patterns, data flow, SaaS posture, deployment topology, scale considerations.
- **Executive brief (`06`)** — one-page Word doc (use the `docx` skill, or `markdown-to-fdd` if present). Distilled, signed-document-grade.
- **Project manager (`07`)** — **default = product literacy primer** (the customer-implementation PM needs to understand the product they're rolling out, not internal phase-gate planning). Confirm with user if ambiguous.
- **Industry primer (`08`)** — the business the app serves, plain English. Source from supplied transcripts/dossiers if available.

#### Voice and word choice — avoid AI-cliché vocabulary

Pack content gets read by humans whose first impression is shaped by the second sentence. The fastest way to look like a stock LLM is to reach for the small vocabulary of AI-ish words. Strip them.

**The single hardest rule: do not use the word "spine."** No "positioning spine," no "narrative spine," no "structural spine," no "spine of the platform." It is a stock LLM tell. If the structural concept is real, say what it actually is — *the pillar order*, *the through-line*, *the operating model*, *the load-bearing claim*. "Spine" gets edited out on first read every time.

**Other words that flag generated text — replace, don't soften:**

- "leverage" (use "use")
- "delve" / "delve into" (use "look at", "open")
- "tapestry" / "rich tapestry of" (just describe what's there)
- "navigate the landscape" / "the landscape of X"
- "embark on a journey" / "this journey" (use "this work", "this build")
- "unlock" / "unleash" / "harness the power of"
- "seamless" / "seamlessly" (almost never true — describe the seam)
- "elevate" / "elevated experience"
- "transformative" / "revolutionize" / "game-changing" / "paradigm shift"
- "synergy" / "synergize"
- "holistic" (unless contrasted with "partial")
- "ecosystem" (over-broad; name the specific surfaces)
- "cutting-edge" / "best-in-class" / "world-class" / "next-generation"
- "robust" / "robust solution"
- "in the realm of" / "in the world of"
- "it's important to note" / "it's worth mentioning" (just say the thing)
- "moreover" / "furthermore" (use "also" or start a new sentence)
- "dive deep" / "deep dive"

**The replacement pattern:** if you wrote a sentence and one of the above words is doing structural work in it, the sentence is probably empty. Rewrite the sentence around what specifically happens, who does it, and what changes — not around the cliché.

**One narrow exception:** when a customer-supplied positioning doc uses one of these terms (e.g., the user's own marketing copy says "the spine of our platform"), quote it verbatim in customer-track materials. Don't strip user-supplied language — strip Claude-generated language.

**Feature library.** One narrative HTML page per feature. Page layout: hero with tagline + 3 key stats, what-it-is section, what-you-see section, key-workflows section, related-screens-and-features section, prev/next nav. Expect 20–30 of these per pack. Generate them from a `feature-metadata.json` file so they're regeneratable. The canonical layout is in `templates/feature-guide.html.reference`.

**Pillar overview pages.** One page per top-level area of the application. Each lists the features in that pillar with cards (number, title, one-sentence pitch, "open feature guide →" link) and includes a narrative intro explaining the pillar's role in the bigger system. Add prev/next navigation across pillars. Expect 4–6 of these per pack. The canonical layout is in `templates/hub-overview.html.reference` (filename retained for backward compatibility; it renders pillar pages).

**Landing page — clone the bundled reference, do not improvise.**

The single most common failure mode of this skill is producing a landing page that "kinda looks like" the bundled template but isn't quite right — wrong gradient, missing sticky nav, role cards that don't have the right hover treatment, audience-card buttons that don't have both "View HTML" and "Download PPTX". This happens when the agent writes the page from scratch by interpreting prose guidance. **Don't do that.** The bundled file `templates/index.html.reference` IS the visual standard. Clone it.

**Procedure:**

1. `Read` the bundled reference: `~/.claude/skills/hso-learning-pack/templates/index.html.reference`.
2. Copy it verbatim to the target repo as `index.html`.
3. Substitute project-specific content **only**, leaving structure, CSS variables, class names, and section ordering identical:
   - App name in `<title>` and the hero `<h1>`
   - Hero tagline + sub-byline
   - Industry primer pull-quote block (or remove the section if no industry primer)
   - The "Overview" paragraphs (3–4) describing the app in business terms
   - The "What this pack is" table-of-contents card
   - The 7 audience role cards (each preserves `class="card ..."` and the two-button footer `<a class="btn btn-primary" href="01-executive-overview.html">View HTML</a><a class="btn btn-secondary" href="01-executive-overview.pptx">Download PPTX</a>`)
   - The pillar cards in the architecture overview section
   - The screen-gallery thumbnails
   - The Quick-launch button URLs (or replace with `# disabled` placeholder if no live app)
   - The top-right sticky `<nav class="topnav">` anchors
   - Footer text
4. Do NOT rewrite the CSS in the `<style>` block. The CSS IS the visual identity. Edit a color variable in the `:root` selector if rebranding (see "Theme + branding" section); otherwise leave it untouched.
5. Do NOT change section ordering. The order is: sticky top-nav → hero → Insurance Brokerage Primer block (rename for the new domain) → Overview → "What this pack is" → Pick your role → Screen Review section → Quick launch → Footer.
6. Do NOT remove sections that don't apply. Replace their content with project-relevant content instead. If there's truly nothing to put there (e.g., no industry primer source material), comment the block out with an HTML comment naming what it was for — easier to restore later than to recreate.

**Sections to clone exactly (with structural notes):**

- **Top-right sticky menu** (`<nav class="topnav">`). Anchors to in-page sections + a "Quick launch" CTA. Match the existing hover/visibility behavior — that's what tells users where they are.
- **Hero** with the gradient background, `class="hero"` and `class="hero-inner"` wrapper. The hero contains a title, a paragraph tagline, and may contain a 3-stat block (`.hero-stats`). If a stat is a product **count** (skills, SOPs, features), write it open-ended — **`75+`, not `~59`** — the same number appears in ~7 places across the pack (decks, `feature-metadata.json`, hero stats, `index.html`/`architecture.html` prose, the generator narratives, page sidecars) and a hardcoded count drifts the moment the product grows.
- **Start here · 3-stage carousel** (replaces the old single Industry Primer block). A `<section id="primer" class="primer-section">` wrapping a `.primer-carousel` with three stages that share the same 2-column layout. Stage 1 = the industry primer (e.g. `08-industry-primer.*`). Stage 2 = an adjacent-vertical primer — a curated subset of the customer-specific modules covering one focused sub-domain (e.g. a vertical-specific track drawn from modules 03–06 of the customer primer). Stage 3 = the full customer-specific primer landing page + per-module mini-cards for the 6 customer modules. Each stage's left column has the eyebrow ("Stage N · …"), title, lede, the View/⬇ PPTX/▶ Watch trio, and a meta line; the right column is pull-quotes on stage 1 and a `.module-mini-grid` of 4–6 mini-cards on stages 2–3. Nav controls — left/right arrows + dot indicators — live in a `.primer-stage-nav` header. JS lives near `</body>` and uses `translateX(-N×100%)` for the slide animation, ArrowLeft/ArrowRight keyboard nav inside the carousel region, and disables the prev/next button at the ends. Markup, CSS, and JS are in `templates/index.html.reference` — copy verbatim, then rewrite Stage 2 / Stage 3 content for the target domain.
- **Overview** narrative card with 3–4 paragraphs.
- **"What this pack is"** — a single card listing the artifacts in the pack.
- **Pick your role** — grid of 7 `.card` items, each with class modifier (`.card.executive`, `.card.sales`, etc.), an `.card-icon` block, an `<h3>`, a body paragraph, a meta line, and a footer with the three-button trio (View / ⬇ PPTX / ▶ Watch). Buttons are short-labelled and `flex: 1` within `.card-links` so they sit equal-width in one row (no wrap). The watch button class is `btn-watch` and includes `target="_blank" rel="noopener"` for the right-click-opens-in-new-tab fallback. Primary click is intercepted by the video modal (next item).
- **Video modal** — a single `<dialog id="video-modal">` near `</body>` that plays narrated MP4s inline without leaving the landing page. Resizable from the bottom-right corner (CSS `resize: both`). Theatre-mode toggle (⛶ button or `F` key) for near-fullscreen. Native HTML5 video controls give the user a true-fullscreen button on top of all this. ESC closes natively. Click-outside closes. Right/middle/Ctrl-click on the watch button still navigates to the MP4 directly. The modal intercepts clicks on any `<a>` matching `a.btn-watch, a.deck-btn-watch, a.feat-card-deck-watch, a.mm-watch` — add new watch-button classes to that selector if you introduce additional card layouts (e.g. the carousel's mini-cards use `a.mm-watch`). Markup, CSS, and JS are all bundled in `templates/index.html.reference` — copy verbatim into target projects.
- **Application Screen Review** — a section with a "screen gallery" of thumbnail tiles and a button to `screens-library.html`.
- **Quick launch** — bold cards linking to the live app URLs.
- **Footer** — slim, navy background, links to pack-level resources.

Use the same procedure for `feature-library.html`, `screens-library.html`, individual feature pages, individual screen pages, and pillar overview pages. Each has a `*.reference` file in `templates/`.

**Architecture / integration topology diagram.**

The reference `index.html` contains an inline SVG topology diagram in the "Application Architecture" section showing the system in horizontal layers — **USERS → APPS → DATA → INTEGRATION → EXTERNAL** — with rectangles for each component and arrows between layers. There's also a standalone `architecture.html` page with a more detailed version of the same diagram.

This is a load-bearing visual: it's the first thing technical-audience readers look at. Skipping it makes the pack feel incomplete. **Do not omit, redraw from scratch, or replace it with a generic block diagram.**

Procedure to adapt:

1. Open `templates/index.html.reference` and locate the `<svg>` block inside the architecture section (search for `<text ...>USERS</text>` and the surrounding `<svg>` parent).
2. Open `templates/architecture.html.reference` for the standalone-page version.
3. From your Phase 1 code inventory, identify the layers for the target app. Adapt with the same five-layer pattern when possible:
   - **USERS** — who logs in / who consumes the system (internal staff roles vs. external users)
   - **APPS** — the top-level deployed applications (Blazor apps, React frontends, microservices with UIs)
   - **DATA** — the database(s), data warehouse(s), key shared persistence layers
   - **INTEGRATION** — middleware, message buses, integration adapters, API gateways
   - **EXTERNAL** — third-party systems the app talks to (carriers, recordkeepers, ERPs, identity providers, payment processors)
4. Edit the SVG `<rect>` + `<text>` pairs in place — keep the layout grid, the gradient fills (`url(#navyGrad)`), the cyan/teal accent strokes, the arrow markers, the row labels. **Substitute the text and rectangle counts; don't restructure the SVG.**
5. Some apps don't fit five layers cleanly. If you need a four-layer or six-layer adaptation, keep the visual treatment (gradient app boxes, cyan-stroked DB pill, dashed external-system rectangles, labeled arrows) but change row count. Don't introduce a new visual language.
6. If your Phase 1 inventory revealed integrations the original diagram doesn't show, add them to the EXTERNAL row — keep the dashed-border treatment.
7. Update the standalone `architecture.html` with the same layer adaptations. It's the deeper version that gets linked from the landing-page diagram via a "Full architecture →" button.

If the agent skips this section: the pack will feel hollow for the technical-audience reader. Confirm visually that the topology renders, components are labeled with real names from the codebase (not placeholders), and arrows flow in plausible directions before declaring the landing page done. To actually *see* it — and catch caption overflow that never shows in the markup — wrap the `<svg>` in a tiny HTML file and screenshot it with headless Edge/Chrome (`--headless --screenshot=out.png`), then look at the PNG before you ship.

### Phase 4 — Screen capture

> **No reachable / populated environment? (Decided in Phase 2.)** Don't fake a screen library. Replace it with **data-model + architecture diagrams** plus **form-layout descriptions read straight from the solution XML** (or via `hso-dataverse-ui-config` `AnalyzeForm`): for each key form, list its tabs, sections, columns, and subgrids in reading order — that's a faithful "what you'd see" walkthrough without a screenshot. The diagrams (the ERD and the architecture SVG) carry more weight here. When the environment later gets the app + sample data, run this phase for real and swap the descriptions for captures. This is the **defer-live-capture** path; it's a legitimate finished pack, not a degraded one.

Goal: a screenshot of every meaningful **app surface** of the live model-driven app — **showing real data, not empty states** — plus a one-page narrative walkthrough per surface. The surfaces are: a **record form** (per table; one entry per form if a table has several), a **saved view / grid**, a **dashboard**, a **business-process-flow stage**, and any **custom page**.

**Use Playwright** for capture. Bundled at `scripts/capture-screenshots.ps1` — adapt the URL list per app.

**Model-driven app deep-link URLs** (so you land on a specific surface, not the app home):

- App home: `https://<org>.crm.dynamics.com/main.aspx?appid=<AppModuleId>`
- A view/grid: `…?appid=<AppModuleId>&pagetype=entitylist&etn=<table_logicalname>&viewid=<savedqueryid>`
- A specific record form: `…?appid=<AppModuleId>&pagetype=entityrecord&etn=<table_logicalname>&id=<recordGuid>`
- A dashboard: `…?appid=<AppModuleId>&pagetype=dashboard&id=<dashboardid>`
- A custom page: `…?appid=<AppModuleId>&pagetype=custom&name=<custompage_uniquename>`

Pull the `AppModuleId`, table logical names, and view/dashboard ids from the solution XML (Phase 1); pull good record GUIDs from the sample-data load or via `hso-dataverse-data` / `hso-fetchxml-queries`.

**Authentication pattern:**

1. Launch a real browser window (`headless: false` — the user can see what's happening).
2. Navigate to the org URL. **User logs in interactively the first time** (Entra / SSO). Save storage state to a JSON file.
3. For subsequent runs, load storage state — no re-login needed.
4. For each surface, navigate to its deep-link URL, wait for it to settle (`networkidle` + an explicit wait for the Unified Interface to finish rendering the form/grid — typically **6–10 seconds**; the UCI hydrates slowly), and capture a full-page PNG.
5. Save screenshots into `screens/`. Per the project convention, the pack's screenshots live under the pack folder (mirror `agent/work/testing/screenshots/` discipline — never the repo root).

#### Finding good data — the hard part

A captured screenshot that shows an empty grid, a "No data found" message, or a `Test1 / Acme Demo` placeholder destroys the credibility of the entire pack. Spend the time to find real data. This is the #1 source of rework — plan for it.

**Before any automated capture run, do a manual walkthrough.** Open the app in your own browser, sign in, and visit every screen on the candidate list. For each one ask:

- Does this screen *have* data right now? If no, **why not** — and how would a real user get data here?
- Is this data realistic (real customer names, real carriers, recent dates) or is it obviously seed data?
- Are there license banners, watermarks, or trial-version cruft on top of the UI?
- Is there a *better URL* (different environment, different tenant) that has cleaner data?

Then act on the answers:

1. **Right app, right data set.** A shared config/demo org may have several apps installed and several data sets. **Ask the user which `appid` and which records are the cleanest demo story — they know.** Load the project's `SampleData/` if the org is empty.
2. **Empty grid? Check the view selector and filters.** A grid that says "No data" usually means "no data in *this* view" — switch the view (the dropdown at the top-left of the grid), clear the "Active <table>" filter, or widen the date range. Some forms only populate a subgrid once a parent field is set; *find that pattern.*
3. **Form tabs are separate surfaces.** A record form with tabs along the top (General, Billing, Collections, Related) is a workflow chain — **each tab worth showing is its own entry** in `screens-metadata.json`. Capturing only the default tab buries most of the form. Use the deep-link plus a click on the tab, or describe each tab from the form XML.
4. **The Unified Interface virtualizes grids and lazy-loads tabs.** Rows and non-default tabs may not be in the DOM until scrolled/clicked. Wait for the specific grid/tab to render before capturing; if a `locator('text=Foo')` click fails on a row you can see, it's virtualization — scroll the grid via `page.evaluate` first.
5. **The record form is the real surface; the view is the way in.** A view/grid is mostly a navigation step — the meaningful UI is the record form you open by clicking a row (or by deep-linking with the record GUID). Capture the *form*, not just the list, for each table that has a rich form.
6. **Cross-check the surface list against the feature inventory.** If `FEATURES.md` lists a "Reconciliation" feature but the Reconciliation form looks empty, the demo data doesn't cover it yet — flag it to the user rather than shipping an empty screenshot. A BPF feature means capturing each **BPF stage**, not one static form.
7. **Capture each meaningful state.** "Empty" is rarely interesting; a form with a populated header, an active BPF bar, and a subgrid showing related child rows tells the story. For dashboards, make sure the charts have rendered (they load after the grid).
8. **Ask the user explicitly:** "Walk me through three or four records that look good right now and tell me how you got there." The user knows the demo set. Their guided tour saves hours of trial-and-error.

#### Iteration discipline

Don't try to capture all 50 screens in one batch on the first pass. Pattern that works:

1. Capture 3–5 screens. Look at the results. Are they showing real data with no cruft?
2. Adjust capture timings and selectors for any that came up blank or cropped.
3. Now batch the rest.
4. Spot-check the batch output. **Re-capture anything < 50 KB** — a 45 KB screenshot is almost always a page that didn't finish hydrating before the screenshot fired.

Expect to re-capture ~30% of screens at least once across a typical build. Plan for it.

#### Per-screen narrative writing

Each captured screen gets a `screen-<id>.html` page generated from `screens-metadata.json`. Fill in:

- **`what_it_is`** — one paragraph naming the screen and its place in the workflow
- **`what_you_see`** — describe the visible UI elements in reading order: the form's tabs, sections, columns, subgrids, the BPF bar, the command-bar buttons. You can pre-write this from the form XML even before capture. *Resist the urge to fabricate;* if you don't know what a column means, read its `Entity.xml` definition or leave it for the user
- **`data_sources`** — which table(s) the surface reads/writes, the key relationships feeding its subgrids, and any plugin/flow/integration that populates it (e.g. "Billing Events subgrid, fed by the BillingEventService plugin on the parent subscription")
- **`workflow_context`** — what came before this surface, what comes after (often a BPF stage transition or a related-record navigation)
- **`vocabulary`** — domain terms used on the screen, with definitions
- **`questions`** — "things to think about" prompts for the reader
- **`related`** — other screen IDs and feature IDs that connect to this one

The `related` field powers cross-linking — make sure both ends agree (if Screen A says related-to-Screen-B, Screen B should list Screen A too).

**Generate per-screen guides.** Each captured screen gets a `screen-<id>.html` page. Schema (in `screens-metadata.json`):

```json
{
  "id": "customer-subscription-form",
  "app": "<AppDisplayName>",
  "group": "<Pillar Name>",
  "title": "Customer Subscription — Billing tab",
  "subtitle": "The subscription instance that drives billing",
  "surface_type": "form",
  "entity": "hso_customersubscription",
  "route": "?pagetype=entityrecord&etn=hso_customersubscription&id=<guid>",
  "screenshot": "screens/customer-subscription-form.png",
  "what_it_is": "...",
  "what_you_see": "...",
  "data_sources": "...",
  "workflow_context": "...",
  "vocabulary": ["auto-pay", "locked royalty rate", "gateway customer id"],
  "questions": ["Why is the royalty rate locked at subscription creation?"],
  "related": ["subscription-plan-form", "billing-event-form"]
}
```

`surface_type` is one of `form` | `view` | `dashboard` | `bpf-stage` | `custom-page`; `entity` is the table logical name; `route` is the deep-link query string appended to `main.aspx?appid=<AppModuleId>`. Generate the HTML pages with `scripts/generate-screen-guides.py` (driven by `screens-metadata.json`). Each page includes a hero, the screenshot, the metadata sections, a vocabulary glossary, "questions to think about," and prev/next nav across the full surface list.

### Phase 5 — Master PDF assembly

Goal: every HTML page rendered to PDF, then merged into one massive `<App>-Learning-Pack.pdf` (~30 MB, ~500 pages) for AI ingestion or instructor-led course generation.

**One-script pipeline:**

- `scripts/make-pack-pdf.py` does both steps in Python:
  1. **Render every HTML to PDF** via Playwright async — open each page in headless Chrome, wait for fonts and images, print to PDF. Marp slide HTML files (`01–08-*.html`) render landscape 16:9; all other pages render portrait US Letter. Local screenshots get embedded via `file://` URLs.
  2. **Merge PDFs in narrative order** via `pypdf`. Order: landing → industry primer → audience decks (1–8) → feature library + each feature guide → pillar overview pages + screens library + each screen guide → reference docs. Bookmarks added per major section.
  3. Intermediate PDFs land in `_pdf-stage/` (gitignored — regeneratable).

A typical pack produces a master PDF in the ~25–35 MB / 400–600 page / 80–100 bookmark range. If yours comes out dramatically smaller, you probably skipped a section (most often the screen library or the feature library).

### Phase 6 — Video narration (optional)

Turn each audience deck into a narrated MP4 using local TTS — no API costs, no cloud dependencies. A typical narrated deck renders at ~10–25 minutes / 20–40 MB / $0 per deck on a modern Intel Core Ultra.

**Pipeline (all bundled):**

1. **Per-slide narration JSON** — `<deck>.narration.json` next to the `.md`. Each entry is a natural, conversational paragraph in teaching voice. **Author these in-chat** rather than relying on text-to-speech parsing the slide markdown — Kokoro reads `$72` as "dollar 72", `**bold**` as "asterisk asterisk bold asterisk asterisk", and `&amp;` as "and amp". Hand-writing the narration sidesteps all of it. See `templates/08-industry-primer.narration.json.reference` for the format and tone.

2. **`scripts/narrate-deck.py`** — reads the narration JSON, calls Kokoro-82M (CPU-only, free, local) to synthesize per-slide WAVs, FFmpeg-stitches per-slide segments. Run on **Windows-native Python**, not WSL — ONNX Runtime sees all cores cleanly there (1.8× realtime vs. 0.7× in WSL). The script's text-normalizer also handles `$N`, `N%`, `M&A`, `401(k)`, `3(21)/3(38)/408(b)(2)`, etc. as a safety net if you ever fall back to markdown parsing.

3. **`scripts/narrate-pptx.ps1`** — exports each slide of the existing `.pptx` to PNG via PowerPoint COM automation (pixel-perfect match to what you see when opening the file), then assembles per-slide segments and concatenates into the final MP4. Prefer this over `narrate-deck.py`'s built-in Marp PNG path — the PPTX is the canonical visual artifact.

4. **`scripts/narrate-all.ps1`** — batch wrapper. Discovers every deck that has both a `.narration.json` and a `.pptx` and renders all of them. Idempotent; cached WAVs are reused across runs.

   **Voice randomization (default behavior):** the pack should feel like a small team narrated it, not one robot. By default the script assigns each deck a voice via hash-based deterministic random pick from four voices: `af_heart` (American female, warm), `am_michael` (American male, deeper), `bf_emma` (British female, polished), `bm_george` (British male, authoritative). Together they form a balanced team across gender and accent. Hash-based means the assignment is stable across re-runs (the same deck always gets the same voice for a given `-RandomSeed`), but every project's decks get a different mix.

   Override paths:
   - `-Voice af_heart` — every deck uses that single voice (useful for unified-narrator decks)
   - `-VoiceMapFile voice-map.json` — explicit per-deck mapping: `{ "01-executive-overview": "bf_emma", "02-sales-enablement": "bm_george", ... }`. Any deck not in the map falls back to the random pick.
   - `-RandomSeed 42` — change the deterministic distribution if you don't like the default pairing.

5. **`scripts/kokoro-smoke-test.py`** — one-shot CLI for testing voice quality before committing to a full deck. `python kokoro-smoke-test.py <deck.md> 3 af_heart` renders the first 3 slides as a single WAV.

**Pronunciation clarification — MANDATORY before rendering.**

Kokoro reads tokens with no idea what they mean. `ITSM` becomes "itsum". `MSP` becomes a mumble. `iNextITSM` becomes whatever the phonemizer guesses. `.NET` may become "dot N E T" or "dot nuh-et" depending on context. The fix is to spell ambiguous tokens phonetically in the narration JSON *before* synthesis — and to confirm pronunciations with the user, not guess.

**The single most useful rule: ALL-CAPS = letters, Title Case = word.** Kokoro reads `SAP` as "S-A-P" and `Sap` as "sap". If a brand or acronym is genuinely *spoken* as a word — `NASA` ("Nasa"), `MARS` ("Mars"), `GIANT` ("Giant") — the fix is a one-character casing change, not phonetic spelling. Conversely, if the source text already has Title Case but Kokoro is still spelling it out, you have a different problem (likely the phonemizer guessing on an unfamiliar token — fall back to phonetic spelling).

**Tooling: `narration-vocab.json` (per-project pronunciation file).** Drop a file named `narration-vocab.json` at the project root (or next to a deck) and `narrate-deck.py` applies whole-word, case-sensitive substitutions to *both* markdown-parsed narration and hand-authored narration JSON. The example lives at `templates/narration-vocab.json.example` — copy, prune, and edit. Schema:

```json
{
  "pronunciations": {
    "SAP":     "S-A-P",
    "ERISA":   "uh-RISS-uh",
    "HSO": "H-S-O",
    "iNextITSM": "I-Next I-T-S-M"
  }
}
```

Lookup order: `$NARRATION_VOCAB` env var → `<deck>/narration-vocab.json` → `<repo-root>/narration-vocab.json` → `<repo-root>/scripts/narration-vocab.json`. Longer keys substitute before shorter ones (so `HSO` wins over a plain `OS` rule). Use the vocab file *instead of* editing each narration JSON — it's the audit trail and the one place a future contributor will look.

**Workflow — do this between authoring narration JSON and running `narrate-deck.py`:**

1. **Extract candidate tokens** from every narration JSON. The minimal regex set:
   ```python
   acronyms = re.findall(r'\b[A-Z]{2,6}\b', text)          # ITSM, MSP, CMDB, etc.
   products = re.findall(r'\b[a-z][A-Z][a-zA-Z]+\b', text)  # iNextITSM, bUnit, etc.
   dotted   = re.findall(r'\.[A-Z][a-zA-Z]+', text)         # .NET, .Razor, etc.
   ```
2. **Group findings** into three buckets:
   - **Spell-out as letters** (the default for most acronyms): `ITSM` → `I-T-S-M`. Kokoro respects hyphens between letters and reads each letter separately.
   - **Keep as word** (rare — only when the acronym is genuinely pronounced as a word in the industry): `CAB` ("cab"), `POST` ("post"), `JSON` ("jay-son"), arguably `ITIL` ("eye-til") — but confirm with the user, because Kokoro may butcher it anyway.
   - **Custom phonetic spelling** for product names: `iNextITSM` → `I-Next I-T-S-M`. `.NET` → `dot-net`.
3. **Ask the user with `AskUserQuestion`** — present the ambiguous ones with proposed pronunciations and 2–3 options each. Don't ask about obvious ones (`API` is always letters; nobody says "appy"). Do ask about:
   - **Product names** — first time the agent sees `<CustomerName>` or a product brand
   - **Industry-specific acronyms** that have an established spoken form (`ITIL`, `JWT` — "jot" or "J-W-T"?, `SaaS` — "sass"?, `OAuth` — "oh-auth"?)
   - **Anything containing `.` or unusual punctuation** (`.NET`, `401(k)`, `3(21)`)
4. **Write the substitutions to `narration-vocab.json`** at the repo root (see schema above). Prefer one vocab file over editing each narration JSON — that's the audit trail and the single point of truth. Only edit a narration JSON directly when the natural-language phrasing itself needs to change (e.g. "the platform's *back-office workflows*" reads better than the source's "*BOWs*"); pure pronunciation lives in the vocab file.
5. **Smoke-test ONE deck end-to-end** before kicking off the full batch. Run `narrate-deck.py` on the executive deck only, listen to the first 30 seconds. If a token is still wrong, fix the JSON and re-render before committing 60 minutes to the full pack.

**Don't skip this step.** The failure mode is silent: the agent generates 8 MP4s, deploys them, the user clicks Play, hears "itsum" in slide one, and now we re-author + re-synth all 8 (which is what motivated this section being added). Every pack that ships with mispronounced acronyms erodes credibility — and pack reviewers will judge audio quality more harshly than slide layout.

**Critical traps to avoid** (learned the hard way):

1. **Run Windows-native, not WSL.** WSL VMM overhead + thread topology issues cap throughput at ~0.7× realtime. Windows-native hits ~1.8× realtime on a modern Intel Core Ultra. 2.5× difference for the same machine.
2. **Concat segments with re-encoding, not `-c copy`.** AAC encoder priming samples accumulate across segment boundaries when copy-concatenating, drifting audio ahead of video at every slide. Re-encode the audio during the final concat.
3. **PNG must come from PowerPoint COM, not Marp's re-render.** Re-rendering from `.md` introduces theme-resolution risk — Marp falls back to default styling if the HSO theme CSS isn't on a Windows-readable path. Use the existing `.pptx` as the source of truth.
4. **Hand-author the narration JSON in teaching voice.** "Reading the slide" sounds robotic regardless of TTS quality. Real narration explains *why* the bullets exist, not just *what* they say.
5. **Force UTF-8 stdout on Windows Python.** Default cp1252 console encoding crashes on the `→` `·` `—` characters that appear in pack content. The bundled scripts already do `sys.stdout.reconfigure(encoding="utf-8")` at startup.
6. **The 510-token phoneme limit.** Kokoro errors with `IndexError: 510 is out of bounds` on long narration chunks. The script's `synth_chunk` function recursively splits and retries on `IndexError` — keep that safety net in place.

**Cost + time benchmarks** (for a typical 6-deck pack at ~30 slides each):

- Local Kokoro-82M, Windows-native: **~$0** + **~10-15 min wall clock per deck** + ~1.5x real-time for full pack
- ElevenLabs (cloud, premium quality): **~$50-90 per pack** + faster wall clock
- Hybrid (Kokoro everywhere, ElevenLabs for showcase exec deck): **~$5-10 per pack**

The bundled scripts default to Kokoro. The smoke-test script lets you A/B voices before committing.

**Optional: include videos on the deployed site.** Drop the MP4s alongside the HTML in the pack and add a `▶ Watch narrated` button to each role card on `index.html` (next to "View HTML" and "Download PPTX"). Total weight of all 13 narrated decks ≈ 400 MB; well within Azure SWA limits.

### Phase 6.5 — Cinematic brand intro (optional)

Every HSO Knowledge pack opens with the same 10-second cinematic brand intro — `HSO Knowledge presents → conference room dolly → Manhattan skyline → app-specific two-beat story → ERP UNITE wordmark with HSO logo lockup`. Panels 1–3 and the panel 6 format are universal across every HSO Knowledge product; the middle two beats (panels 4 and 5) are app-specific.

**Two-stage pipeline:**

1. **Storyboard** — a six-panel B&W pencil sketch generated by an image model (Imagen / Gemini / Midjourney). This is the cheap, fast pre-production step where the panel composition, narrative beats, and brand language get locked.
2. **Video** — once the storyboard is approved, the same six panel descriptions feed into a Veo 3 / Gemini Omni prompt (panels 2 + 3 collapse into one dolly+tilt beat for the 10-second video).

**Canonical invocation** — paste this into Claude Code from inside any HSO Knowledge project:

> "Use the hso-learning-pack skill to generate an HSO Knowledge intro storyboard for this app. Use the current knowledge and narration for the primer or other summaries to serve as a basis for the role and purpose of the app to build out the required scenes."

That prompt tells Claude to **derive the panel content from existing project artifacts** — narration JSONs (especially the executive and sales decks), primer markdowns, README, SPEC docs, the landing page hero copy — rather than asking the user to spell out audience, pain, and outcome from scratch. The teaching-voice narration usually already names the chaos this app solves (panel 4) and the outcome it makes possible (panel 5).

**Bundled assets:**

- `templates/storyboard-prompt.txt` — the full prompt template with 8 placeholders, a "how to pick panels 4 and 5" decision section, a story-shape catalog (problem→solution, before→after, many→one, manual→automated, question→answer, setup→payoff), a category cheat sheet (financial / CRM / HR / procurement / manufacturing / field service / compliance / mailroom), and three worked examples across distinct app categories.
- `references/hso-logo.jpg` — official HSO brand mark; attach to every storyboard + video prompt.
- `references/hso-conference-room.jpg` — HSO Manhattan office; defines the look of panels 2 and 4.
- `references/hso-homepage-hero.png` — optional palette backup.
- `references/storyboard-style-example.png` — B&W pencil storyboard style guide; attach to every storyboard prompt.

**Discovery-first workflow** (encoded in the template):

When the canonical invocation fires, the agent should consult, in priority order: (1) `*.narration.json` for teaching-voice positioning, (2) `*-primer.md` for domain context, (3) `README.md` / `SPEC-*.md` / `docs/`, (4) the landing `index.html` hero copy, (5) `CLAUDE.md`. Only ask the user when discovery doesn't surface a candidate — and when you do, ask narrowly ("the exec deck mentions X and Y as the pain — should panel 4 lean on X or Y?"), never re-ask for things the project already states.

The story shape is the most creative call; it's worth surfacing the agent's choice to the user with one short rationale ("problem→solution: panel 4 = carrier statement stack, panel 5 = clean ledger") before committing to the final prompt.

### Phase 7 — Deployment (optional)

Goal: the pack lives at a URL teammates can open in a browser. The reference deploys to **Azure Static Web Apps**, which is generous on the free tier and supports both built-in Entra auth and custom Entra app registrations.

**Deploy pipeline scripts** (PowerShell, in `scripts/`):

- `Deploy-LearningPack.ps1` — main deploy. Caches `-Name`, `-ResourceGroup`, `-Location`, `-AuthMode` in `.deploy-config.json` so subsequent runs need no params. Auto-selects Standard SKU when `AuthMode = Custom`, Free otherwise.
- `Setup-EntraAuth.ps1` — creates Entra app registration, adds redirect URI, generates client secret, pushes `AAD_CLIENT_ID` + `AAD_CLIENT_SECRET` into SWA app settings, ensures Microsoft Graph delegated permissions (openid, profile, email, offline_access, User.Read), grants tenant-wide admin consent. Idempotent.
- `Reset-Deployment.ps1` — nuclear option; deletes the SWA, optionally deletes the Entra app reg, clears cache, redeploys fresh.
- `Diagnose-SwaAuth.ps1` — reads SWA state, app settings, and Entra app reg config; flags the common auth-loop causes.
- `Upgrade-SwaToStandard.ps1` — Free → Standard SKU upgrade ($9/mo) for when custom Entra is needed.

**One-click deploy.** A single command does provisioning + content deploy + auth setup:

```powershell
.\Deploy-LearningPack.ps1 -Name <swa-name> -ResourceGroup <rg>
```

That's it. The script defaults to `-AuthMode Custom`, provisions Standard SKU SWA, deploys the content, then automatically chains into `Setup-EntraAuth.ps1` to create the Entra app registration, generate a client secret, push it into SWA app settings, grant Microsoft Graph permissions (openid + profile + email + offline_access + User.Read), and grant tenant-wide admin consent.

**Fully idempotent** — re-running the same command republishes the app: SWA existence is detected and reused (SKU auto-upgraded to Standard if needed), content is re-staged and redeployed, the Entra app reg is reused (no new secrets unless `-RotateSecret`), Graph permissions and consent are reconciled if drift is detected. Parameters cache to `.deploy-config.json` so the second call onwards needs no args:

```powershell
.\Deploy-LearningPack.ps1                 # re-publish everything (idempotent)
.\Deploy-LearningPack.ps1 -SkipProvision  # skip existence/SKU checks (slightly faster, optional)
```

**Deployment environments — production and staging.** The `-Environment` parameter selects which SWA named environment to deploy to. Defaults to `production`. Any other value (e.g. `staging`, `preview`, `qa`) creates an Azure SWA preview environment on the same SWA resource — same auth config, separate URL, isolated from production. Pick whichever fits the moment:

```powershell
# Production deploy — promotes content to the live URL
.\Deploy-LearningPack.ps1 -Environment production

# Staging / preview deploy — to a parallel URL on the same SWA
.\Deploy-LearningPack.ps1 -Environment staging

# Custom-named env, useful for per-branch previews
.\Deploy-LearningPack.ps1 -Environment qa-feature-foo
```

URL pattern: production lives at the SWA's default hostname; named envs live at `<base>-<env>.<region>.azurestaticapps.net`. For `Custom` auth mode, Deploy-LearningPack.ps1 automatically adds the env's callback URI to the Entra app reg's redirect-URI list (idempotent — re-running is a no-op if already registered). No manual Entra-portal click needed.

Common workflow:
- `staging` for spot-checking before a release
- `production` once verified
- Both run from the same script, same source tree, same parameters — only `-Environment` differs.

`staticwebapp.config.entra-gated.json` uses a relative `post_login_redirect_uri=/` so the same config file works correctly on production AND any named environment without modification (no hardcoded hostnames).

**Don't propose the other modes unless the user asks for them by name.** They exist as escape hatches:

- `None` — public site, no auth. Only if the pack is genuinely public.
- `EasyAuth` — SWA's built-in pre-configured Entra provider on Free SKU. All the config-side fixes below (cache-control, asset whitelist, redirect URI) apply equally to `staticwebapp.config.easy-auth.json` and are already baked in, so the historical sign-in loop modes *will not* recur on a fresh deploy. The one remaining gotcha is a tenant-policy issue, not a config bug: the SWA first-party Microsoft app needs admin consent on tenants that block per-user consent. A tenant admin clicking this URL **once** clears it for every user forever:

  ```
  https://login.microsoftonline.com/<tenant-id>/adminconsent?client_id=<swa-builtin-multitenant-app-id>
  ```

  `Custom` avoids this entirely because the customer creates *their own* app reg whose consent they obviously control. That's why `Custom` is still the default — it sidesteps the policy variable, not because EasyAuth has unsolved bugs.

**The `staticwebapp.config.entra-gated.json` template already bakes in the auth fixes** that historically eat an afternoon to debug from scratch:

1. `Cache-Control: no-store` in `globalHeaders` — caching the 401→login redirect for 5 minutes creates an infinite loop after sign-in. Bundled config uses `no-store`.
2. Static-asset whitelist — `/*.{css,js,png,svg,ico,jpg,jpeg,gif,webp,woff,woff2,ttf,otf,map,json}` is routed with `allowedRoles: ["anonymous", "authenticated"]` BEFORE the gated `/*` route. Otherwise every CSS/JS/image fires its own auth chain and the cookie jar never settles.
3. `post_login_redirect_uri=/` on the 401 redirect — the responseOverride uses a *relative* root path so SWA bounces the user back to the current host's landing page after sign-in. Critically, do NOT hardcode the production URL here — that breaks named environments (e.g. staging users would land on production). The relative `/` works correctly across production AND every preview environment without modification.
4. `auth.identityProviders.azureActiveDirectory.registration.openIdIssuer` pointing at the tenant-specific v2.0 endpoint, with `clientIdSettingName` + `clientSecretSettingName` referencing the app settings that `Setup-EntraAuth.ps1` writes.

**Other operational gotchas (not auth-specific):**

- **Push from Windows `git.exe`, not WSL git** when shipping to Azure DevOps from a Windows + WSL setup. WSL bash can't reach Windows Credential Manager. Use `"/mnt/c/Program Files/Git/cmd/git.exe" push`.
- If the Azure DevOps repo was auto-initialized with a README, **merge with `git merge --allow-unrelated-histories -X ours origin/main`** instead of `git pull --rebase` — rebasing a 200+ file commit through Windows git from WSL hangs reliably on the working-tree rewrite step.

## Inputs the user must supply

Lock these down in Phase 2 before generating anything:

| Input | Required? | Default if not specified |
|---|---|---|
| Dataverse environment URL + `appid` | If you want a live screen library | Defer live capture; use form-layout descriptions + diagrams |
| App + sample data loaded in that env | For live capture | Defer live capture |
| Interactive login to the env | For live capture | Defer live capture |
| Business reference material (`agent/` wiki, transcripts, FDD) | No | Use the project's `agent/` wiki + the spec; fall back to a generic domain primer |
| Featured stakeholders (whose asks to highlight) | No | Highlight none by name; describe capabilities generically |
| Brand theme | No | HSO theme (Navy/Cyan/Teal) |
| Audience list | No | The 7 defaults + business primer |
| Customer-specific track | No | Skip |
| Output destination | No | The repo's deliverables convention (e.g. `agent/work/deliverables/<app>-learning-pack/`), else `docs/learning-packs/`, else a sibling repo |
| Deploy target | No | Skip (build artifacts only) |

## Bundled assets

The skill folder contains the canonical, generic versions of:

- `references/dataverse-mda-discovery.md` — **read before Phase 1 Step 2.** How to inventory a model-driven app from the solution export (AppModule, sitemap, Entity.xml, forms, views, dashboards, BPFs, plugins, flows) and which `hso-dataverse-*` skill to use for each live-metadata gap. The Dataverse-specific spine of discovery.
- `references/non-app-archetypes.md` — **read only if Step 0 reclassified the product** as something other than a model-driven app (toolkit / SDK / CLI / AI-accelerator / methodology). Overrides the app-centric defaults for pillars, audiences, the primer, and the screen library; covers standalone deep-dive pages, the de-intimidation audience track, iterating on a pack, and the Forge USA worked example.
- `themes/hso-theme.css` — default brand CSS. Marp-compatible. Variables at the top — easy to fork for other brands.
- `themes/marp-authoring-guide.md` — Marp directives + HSO theme reference. (Or reuse the one in `presentation-builder/`.)
- `templates/index.html.reference` — **THE landing page**. Clone-and-adapt; don't rewrite from scratch. Includes the inline SVG topology diagram.
- `templates/architecture.html.reference` — **standalone architecture page** with the deeper system topology diagram. Linked from the landing page's "Full architecture →" button.
- `templates/feature-library.html.reference` — feature index page (grid of all features grouped by pillar).
- `templates/screens-library.html.reference` — screens index page (grid of all captured screens by group).
- `templates/feature-guide.html.reference` — representative individual feature page.
- `templates/screen-guide.html.reference` — representative individual screen walkthrough.
- `templates/hub-overview.html.reference` — pillar overview page with feature cards + prev/next nav.
- `templates/customer-primer-landing.html.example` — customer-specific track landing page (only used when building a customer-specific primer for a named engagement).
- `templates/0[1-8]-*.md.reference` — **canonical Marp deck markdown** for each audience (executive, sales, functional, technical, enterprise, exec brief, project manager, industry primer). Open these to copy the frontmatter, slide class usage, and per-audience voice. Don't author from scratch — adapt these.
- `scripts/capture-screenshots.ps1` — PowerShell + Playwright capture template (interactive login, storage-state save/load).
- `scripts/launch-apps.ps1` — helper to launch a list of app URLs in default browser; useful for demo flow.
- `scripts/make-pack-pdf.py` — render every HTML to PDF and merge into master PDF (one script, two steps).
- `scripts/merge-pack-pdf.py` — standalone merger if you've already rendered the individual PDFs another way.
- `scripts/generate-feature-guides.py` — render feature pages from `feature-metadata.json` (also generates pillar overviews from a `HUB_NARRATIVES` Python dict embedded in the script; variable name retained for backward compatibility — its contents describe pillars).
- `scripts/generate-screen-guides.py` — render screen pages from `screens-metadata.json`.
- `scripts/md-to-hso-html.py` — convert markdown to HSO-themed HTML pages (used for ad-hoc pages outside the metadata-driven generators).
- `scripts/render-doc-page.py` — **the generic standalone-page renderer.** `python scripts/render-doc-page.py <name>` renders `<name>.md` (+ optional `<name>.page.json` hero/CTA sidecar) into the pack chrome. Use for setup pages, role-supplement pages, and any load-bearing-concept deep-dive (see `references/non-app-archetypes.md` §7). Styles tables, code blocks, and blockquotes; first paragraph becomes the lede.
- `scripts/generate-customer-primer.py.example` — reference template for customer-specific primer tracks (parallel to the audience tracks). Rename + adapt content.
- `scripts/build-customer-primer.sh.example` — one-shot build script chaining Python gen → Marp PPTX → Marp slide HTML for a customer primer.

When invoked, **copy these into the pack folder** (the repo's deliverables location — e.g. `agent/work/deliverables/<app>-learning-pack/scripts/` and `.../themes/`). The user can adapt them in place and commit them. Don't keep them in the skill folder and reference across paths — that's brittle.

## What "good" looks like (size and shape)

A well-formed pack typically lands in this range. If yours comes out far below, you skipped a phase.

| Artifact | Typical count / size |
|---|---|
| Audience decks | 7 decks (HTML + PPTX) + 1 business primer + 1 executive brief (Word) |
| Feature guides | 20–30, driven by `feature-metadata.json` (one per business capability, not per table) |
| Pillar overview pages | 4–6, one per sitemap Area / functional table group |
| Screen walkthroughs | 40–110 app surfaces (forms / views / dashboards / BPF stages), driven by `screens-metadata.json` — or, on the defer-live-capture path, form-layout descriptions + diagrams |
| Master PDF | ~25–35 MB, 400–600 pages, 80–100 bookmarks |
| Deploy | Azure SWA with one of three auth modes (Custom default) |
| Optional customer-specific track | 6 modules + landing page + slide HTML + PPTX |

When in doubt about styling, structure, or look-and-feel, the bundled `templates/*.reference` files inside this skill are the canonical examples. Open them and copy verbatim before adapting.

## Toolchain dependencies

### Required (the skill won't function without these)

- **Node 18+** with `npx` — used by Marp CLI (PPTX + slide HTML rendering), Playwright (screen capture, PDF rendering).
- **Python 3.10+** with pip — used by every generator script and the PDF merger.
  - `pip install markdown-it-py pypdf playwright`
  - `playwright install chromium` (one-time, for headless rendering)
- **Microsoft Edge or Chrome** — Marp invokes a headless browser for PPTX export. On WSL the wrapper defaults to Windows Edge at the standard install path; override via `BROWSER_PATH` env var.

### Required only for the deploy phase

- **Azure CLI (`az`)** — for SWA provisioning + Entra app-reg setup.
- **PowerShell 7 (`pwsh.exe`)** — runs the deploy/setup/diagnose scripts.

### Optional (nice to have, skill works without them)

- **`faster-whisper`** — `pip install faster-whisper`, only if you want to transcribe audio/video knowledge-transfer recordings for the industry primer. Otherwise supply pre-written dossiers.
- **`markdown-to-fdd` skill** — handy for the one-page executive brief in Word. If absent, render the brief in HTML/PPTX form instead and the skill is none the worse.

### Other skills referenced (all bundled or optional)

This skill is **self-contained** — every script and asset it needs is in this folder. Two other skills are *referenced* in the workflow:

- **`presentation-builder`** — sibling skill that renders standalone decks. This skill bundles its own copy of `make-deck.sh` and `hso-theme.css` in `scripts/` and `themes/`, so `presentation-builder` is not required to ship. If the recipient has it installed, the generators can call its wrapper directly; if not, the bundled copies work identically.
- **`markdown-to-fdd`** — optional, for the executive brief Word output. If absent, drop the Word brief or fall back to HTML.

**Bottom line for packaging:** zip `~/.claude/skills/hso-learning-pack/` and ship it as a single skill. The recipient only needs Node, Python, and a Chromium-based browser at the system level. If they want Word exports or audio transcription, the optional skills can be added later without changing this one.

## Where to put output

Three patterns, pick based on context:

1. **The repo's deliverables convention** — preferred. In an HSO Dataverse project that's usually `agent/work/deliverables/<app>-learning-pack/` (committed alongside the other client-facing artifacts). Check `agent/schema.md` / `agent/index.md` for where finished deliverables go. If the repo has no such convention, fall back to `docs/learning-packs/` at the root.
2. **Sibling repo** at `<parent>/<App>-Learning-Pack/` — if the source repo gitignores the deliverables path or the pack is deployed separately. Init a new git repo and copy generated files in.
3. **Standalone folder** if the user just wants the artifacts without git tracking.

When creating a sibling repo and the remote already has an auto-init README, use `git merge --allow-unrelated-histories -X ours origin/main` instead of `git pull --rebase` — rebasing a 200+ file commit through Windows git from WSL hangs reliably on the working-tree rewrite step.

## Don'ts

- **Don't try to do every phase in one giant burst.** Checkpoint between phases. Each phase has different signal-quality needs from the user.
- **Don't fabricate features.** If you can't find evidence of a feature in the solution (a table, form, plugin, or flow), don't write a guide for it. Better to ship 18 real features than 25 if 7 are made up.
- **Don't claim a "Gap" in capability without reading the metadata.** Assumptions about a "narrow" schema are how a real capability gets mis-marked as out-of-scope. A 30-second read of the `Entity.xml` and its option sets often reveals the schema is more flexible than a spec implies. **Read the table + option-set definitions before declaring scope limitations.**
- **Don't mistake a metadata detail for a feature.** A single option-set value, one extra column, or a standard CE table the app rides on is not a "feature." A feature is a business capability backed by a *set* of components. (See `references/dataverse-mda-discovery.md`.)
- **Don't invoke Dataverse MCP tools in HSO repos.** Schema/data/option-set lookups go through the `hso-dataverse-*` skills (routed via `powershell.exe`), never `mcp__Dataverse*`.
- **Don't write the master PDF until the HTML is right.** The PDF is rendered FROM the HTML. Iteration on PDF before HTML is settled wastes 5-minute render cycles.
- **Don't put screenshot capture before HTML generation.** Screenshots take longer than text, and you might rename screens or restructure during HTML iteration. Capture late.
- **Don't deploy with custom Entra on the Free SKU.** It will silently ignore your `AAD_CLIENT_ID`/`AAD_CLIENT_SECRET` and create a loopback. Free SKU only supports the built-in pre-configured Entra provider.
- **Don't add `Co-Authored-By` lines** to commits in this user's repos (per their global `CLAUDE.md`).

## Variations on the pattern

Once the base pack is built, common extensions:

- **Customer-specific primer track.** When a specific customer engagement is the use case, build a parallel 6-module primer track for that customer (industry context + their business + how it maps to the product). The bundled `templates/customer-primer-landing.html.example` is the entry-point layout. Driven by a deep-research dossier the user supplies.
- **Per-environment screen sets.** Some apps have multiple environments (dev/QA/UAT, or internal/external portals). Capture each as a separate `screens-<env>/` folder and either fold them all into one screen library or generate per-environment sub-libraries.
- **Tabbed-workflow expansion.** When a single screen has multiple tabs that each represent a distinct workflow (a 6-tab detail page is common), treat each tab as its own screen and capture/document them separately. Otherwise the screen library buries critical functionality behind a single thumbnail.
- **Optional Word version** of major decks. Some leadership prefers Word over PowerPoint for the executive brief. Use the `docx` skill (or `markdown-to-fdd`).

That's the playbook. Adapt liberally. When stuck on look-and-feel, open the bundled `templates/*.reference` files — they are the canonical examples.
