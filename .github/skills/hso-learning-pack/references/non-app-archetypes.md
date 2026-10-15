# Non-application archetypes — adaptations

Read this when **Step 0** classified the product as anything other than a deployed business application: a developer toolkit / SDK / library, an AI-agent / skills + methodology accelerator, a CLI / framework / platform, or a methodology / standards body.

The main `SKILL.md` workflow still runs end-to-end. This file swaps in the right move at the **four points where the app-centric defaults break**, then adds two patterns (standalone deep-dive pages, iterating on a pack) and a worked example.

## Contents

1. The four override points (at a glance)
2. Pillars for non-app products
3. The standards / knowledge layer is usually the real IP
4. Audiences — tailor the set, and the "de-intimidation" track
5. The primer — paradigm, not industry
6. Visuals without a UI
7. Standalone deep-dive pages (beyond the feature template)
8. Grounding in source when there are no DTOs
9. Iterating on an existing pack
10. Worked example — the Forge USA accelerator pack
11. Organize for the reader — IA, and the reference pages it implies

---

## 1. The four override points (at a glance)

| Phase | App default | Non-app override |
|---|---|---|
| 1 — Pillars | Business-domain / lifecycle areas of the app | Delivery lifecycle the product *supports* + a "how the machine works" substrate pillar; promote the standards layer |
| 2 — Audiences | The fixed 7 roles | The roles the product actually serves; add a **de-intimidation track** for low-code/functional readers |
| 3 — Primer | Industry the app serves | The **paradigm / working-model** the reader must accept first |
| 4 — Screens | Playwright capture of a live UI | Annotated **tool-session walkthroughs** + diagrams, or skip |

Everything else (feature library, pillar pages, decks, master PDF, deploy, the HSO theme, the landing-page clone) is unchanged.

---

## 2. Pillars for non-app products

Business-domain pillars assume the product *is* the business. A toolkit isn't — it's the thing a team uses to do the business. So decompose by **what the product helps its users do**, in order. Two strategies, usually combined:

- **Delivery / usage lifecycle** — the stages the product shepherds its users through. For a delivery accelerator: *get set up → capture/discover → design → build → ship → operate*. Each stage is a pillar that tells a complete sub-story. Read the pillar names aloud as a sentence; if it isn't a coherent journey, regroup.
- **A "substrate" pillar, always last** — "how the machine itself works": the extension model, the plugin/skill taxonomy, the governance, the contribution model. This is the pillar power-users and maintainers care about, and it's where the product's cleverness lives.

Keep it 3–6. The same card grid and `feature-metadata.json` → `generate-feature-guides.py` pipeline renders these pillars; the `HUB_NARRATIVES` dict in that script just holds your lifecycle pillars instead of business hubs.

## 3. The standards / knowledge layer is usually the real IP

The single most important judgement for an accelerator/methodology product: **find the layer that encodes the opinion**, and treat it as a headline, not a footnote. In a delivery accelerator it's the SOPs / best-practices / rules; in an SDK it might be the conventions and the type system; in a CLI it's the workflow it enforces. The *tools* (skills, commands, generators) are only as good as this layer because they read from it.

When a product has such a layer:

- Give it a **prominent pillar** (often the substrate pillar, or its own).
- Consider a **standalone deep-dive page** beyond the feature card (see §7) — the layer usually has enough to say (how it's authored, how it's kept current, how it powers the tools, how people contribute) to justify its own narrative page, linked from the landing page, the architecture page, and the feature guide.
- Surface its **trust mechanics**: where claims are sourced, how opinions are attributed and dated, how the layer is reviewed and kept current, and **how an expert contributes** — turning one person's hard-won lesson into the team's default is a story worth telling explicitly.

## 4. Audiences — tailor the set, and the "de-intimidation" track

Don't ship the 7 default roles unless the product actually serves them. Pick the roles *this* product has. For an internal toolkit serving mixed-skill practitioners, the highest-value split is by **skill comfort**, not job title:

- **The low-code / functional reader** — comfortable in a config UI or a business role, *intimidated by the developer tooling* (editor, terminal, "using an LLM to write code"). This is the hardest and most important track.
- **The pro-code / technical reader** — a developer who wants depth: architecture, the extension model, the internals.
- **A buy-in / practice-lead track** — the "why we invest in this" case (outcomes, consistency, governance, scale), for the person deciding to adopt it.

**The de-intimidation design principle** (for the low-code track — this is what made the Forge functional deck land): *never lead with the scary tooling.* Name the fear out loud and answer it. Show the product is driven **conversationally** (you describe what you want; it does it; you review where you already work). Keep the reader's familiar surface (the config portal, the business view) as home, and frame the editor/terminal as "where the assistant keeps its notes," not where the reader has to live. Flag clearly which work needs a specialist vs. which the reader can own — an honest split (e.g. "~90% is yours, ~10% needs a developer") is reassuring *and* useful for scoping.

**Roles vs. activities — and the overlay pattern (avoid deck sprawl).** Two different things masquerade as "audiences," and they want different treatments:

- An **activity** (a distinct *kind of work* with its own goal, skills, and guardrails — e.g. *presales* vs. *delivery*) earns its **own track/deck**. Presales' job is to win the deal (demo storyboard, RFP → SOW, reference architecture); that's genuinely different work from delivering, so it gets a standalone deck.
- A **role** (a *seat* within an activity — e.g. the six delivery roles: functional consultant, solution architect, technical consultant, technical architect, PM, engagement manager) usually does **not** earn its own deck. Six near-identical decks is a maintenance trap. Instead, keep one or two **core decks** for the activity (e.g. a Functional core and a Technical core) and add a single **role-supplements page**: a short overlay per role that names the skills that matter for that seat, where it sits in the lifecycle, and its sharpest guardrails, each pointing back to its core. This mirrors how mature curricula already organize ("one core + N overlays") and stays maintainable as roles shift.

The decision rule: *different goal/workflow → own track; same workflow, different seat → overlay.* When the source material already has role overlays (look for a `Role-Supplements/` or similar folder), distill those rather than inventing.

**Setup / onboarding as a first-class track.** If the product needs tooling set up before anyone can use it (install an editor, clone a repo, run a wizard, authenticate), that setup deserves its own prominent **guided page** — not a buried paragraph. Build it as a standalone page (not slides; setup is copy-paste-and-scroll), source it from the product's existing setup docs (e.g. a `Setup-Guide.md` and the repo's own `SETUP.md`), keep the real commands, add a troubleshooting section, and surface it *first* (topnav + the first card in the role grid). It's the thing that unblocks everything else.

Use an `AskUserQuestion` (Phase 2) to confirm the audience set rather than assuming it.

## 5. The primer — paradigm, not industry

The "industry primer" exists because an app's features only make sense once you understand the business it serves. For a toolkit, the equivalent gate is the **paradigm**: the working-model the reader has to accept before anything else lands. For an AI-augmented accelerator that's *"you direct an assistant in plain language; the human stays in charge; the tools encode the standards."* Build it as the "Start here" module (slot `08`, the same primer position), source it from the product's own positioning and the mindset shift it asks for, and write it in plain English. Keep the landing-page primer block; just rewrite its content from "the industry" to "the paradigm."

## 6. Visuals without a UI

Confirm the approach with an `AskUserQuestion` in Phase 2 — offer three options: (a) **capture a live demo** of the product in use (best, needs an environment), (b) **diagrams + annotated tool-session transcripts** (no environment needed), (c) **skip visuals this round**.

If there's no product UI, the "screens" are the product *in action*:

- An **agent / editor session** driving the toolkit (e.g. a Claude Code or Copilot session running a skill), annotated to show the conversational loop.
- A **CLI run** or terminal session.
- The **portal / surface the product configures** (e.g. a Maker Portal, a cloud console) — the place the user reviews what the tool produced.
- The **knowledge base / wiki** the product reads and writes.

Pair these with **diagrams** as the load-bearing visual. The architecture SVG (adapt the bundled `templates/architecture.html.reference` / the inline topology in `index.html.reference`) carries more weight here than for an app — a toolkit's "how it works" is a flow, not a screenshot. Use the five-layer pattern but relabel the rows for the product (e.g. USERS → AI TOOLS → THE ACCELERATOR → CLIENT PROJECTS → PLATFORM). If the user picks "diagrams + transcripts only," skip Phase 4's Playwright capture entirely and invest in the diagrams.

## 7. Standalone deep-dive pages (beyond the feature template)

Most capabilities fit the `feature-guide` template (one card's worth of narrative). A **load-bearing concept** — the standards layer, the security model, the extension framework — sometimes deserves a longer, standalone narrative page that the feature card links *out* to. Build one like this:

1. Write the content as a single markdown file (`<name>.md`) in the pack root. Lead with a short lede paragraph (it gets styled as a lede), then `##` sections. Tables, code blocks, and blockquotes all render.
2. Render it into the pack chrome with the bundled **`scripts/render-doc-page.py`** — the generic standalone-page renderer. Run `python scripts/render-doc-page.py <name>`; it reads `<name>.md` plus an optional `<name>.page.json` sidecar (hero title with `<strong>`, subtitle, eyebrow, breadcrumb, pills, an optional closing CTA card, footer) and writes `<name>.html` in the same hero+section chrome as the rest of the pack. One sidecar per page; fully regeneratable. (Force UTF-8 on Windows: `PYTHONIOENCODING=utf-8 PYTHONUTF8=1`.) For a one-off without a sidecar, `scripts/md-to-hso-html.py` also works.
3. Link it from: the landing page (a dedicated emphasis band, a card in the role grid, and/or a topnav link), the architecture page, and the relevant feature guide (a markdown link in the feature's `what_it_does` / `business_value` — the generator renders markdown, so `[text](page.html)` works).

This is how the Forge pack built `sop-layer.html` (the SOP-layer deep-dive), `setup.html` (the Setup track), and `role-supplements.html` (the six delivery-role overlays) — all from the one generic renderer, each still cross-linked to its feature guide and pillar.

## 8. Grounding in source when there are no DTOs

Phase 1's "read the entities/DTOs/migrations" advice assumes a typed business domain. For these archetypes the load-bearing "types" are different — inventory *those* instead, still with parallel `Explore` subagents, still every claim backed by a file path:

- **Skills / commands / generators** — the units of capability. Read each one's manifest/`SKILL.md`/help text; group them; tag each by which audience it serves.
- **The standards / knowledge layer** — the SOPs, rules, schemas. Read the umbrella/index docs and a few deep ones; find the authoring + governance process docs.
- **The scaffolding / setup path** — the wizard, the init scripts, the distribution mechanism (how the product reaches a consuming project).
- **The knowledge model** — if there's a structured wiki/KB, read its schema and index; understand how the product and its users navigate it.
- **ADRs / decision records** — for a methodology product these *are* the rationale; they explain why rules exist.

A workflow or a fan-out of subagents that drafts grounded content blocks (one per area) and returns them for inline assembly works well here — it keeps every claim sourced while you keep voice control during assembly.

## 9. Iterating on an existing pack

The skill is also the tool for *updates* — adding a section, emphasizing a layer, refreshing content. Don't rebuild from scratch:

- **Feature / pillar pages** come from `feature-metadata.json`. Edit the JSON entry, then re-run `scripts/generate-feature-guides.py <json> --out-dir .` (force UTF-8 stdout on Windows: `PYTHONIOENCODING=utf-8 PYTHONUTF8=1`). It regenerates all feature guides, the library, and the pillar pages idempotently.
- **Decks** are per-file. Edit the Marp markdown, re-render only the changed deck to **both** HTML and PPTX (the PPTX needs Edge/Chrome via `--browser`).
- **A new standalone page** is one markdown file + a render pass (§7).
- **Landing / architecture** are hand-edited HTML — make targeted edits, preserve the CSS.
- **Always re-run the checks**: no leftover from the cloned template (search the old product name), no broken internal links (every `href="*.html"` resolves to a file), balanced sections.
- **Match the existing voice** — read a couple of existing pages/decks first. Honor the bundled voice rules (no "spine", "leverage", "seamless", etc.).

- **Removing a section from the landing page?** Delete it and leave a one-line placeholder comment — do *not* wrap it in an HTML comment if its content contains `--` (PowerShell flags, a `<code>` with `--`, etc.): `--` is invalid inside `<!-- -->` and silently breaks the comment and everything after it.
- **Hand-edited the topology SVG?** Screenshot it before shipping — wrap the `<svg>` in a tiny HTML file and capture it with headless Edge/Chrome (`--headless --screenshot`), then look at the PNG. Caption overflow and cramped boxes don't show in the markup.

**Common update recipes** (the product grew — regenerate the affected slice, not the whole pack):

- *New feature(s) shipped* → add entries to `feature-metadata.json`, then re-run `generate-feature-guides.py`. If a new pillar emerged, add it to the `HUB_NARRATIVES` dict in that script first (and a landing-page pillar card).
- *A capability deserves a deep-dive* → write `<name>.md` + `<name>.page.json`, render with `render-doc-page.py`, and link it from the landing page, the relevant feature guide, and the architecture page (§7).
- *New activity track* → author a new deck (`NN-<activity>.md`), render to HTML + PPTX, add a role-grid card. *New role within an activity* → add a `##` section to the role-supplements page and re-render — don't make a new deck.
- *A whole-pack refresh* → re-run `generate-feature-guides.py` (features + pillars + library), re-render any changed decks (HTML **and** PPTX), re-render standalone pages with `render-doc-page.py`, then the leftover/link/section checks. Consider a small `regenerate.sh` in the pack that chains these so a future contributor runs one command.
- *Always finish with* the verification sweep: search for the previous product name (no leftovers), confirm every `href="*.html"`/`.pptx` resolves, and check `<section>` open/close balance on hand-edited HTML.

## 10. Worked example — the Forge USA accelerator pack

Built with this skill; a concrete template for the AI-agent/accelerator archetype.

- **Product:** HSO's "Forge USA" — a Dataverse/Dynamics 365 delivery accelerator: 75+ Claude Code skills, 120+ SOPs, a four-layer knowledge wiki, and scaffolding scripts that client repos inherit through a filesystem junction. No deployed UI.
- **Pillars (delivery lifecycle + substrate):** Foundations & Onboarding · Capture & Discovery · Design & Data Modeling · Build & Configure (deliberately two-sided: low-code config vs. pro-code) · Deploy & Operate · The Accelerator Substrate.
- **Audiences:** AI-Augmented Delivery **primer** (paradigm, "start here") · **Functional Consultant** (the de-intimidation track) · **Technical Consultant** (developer depth) · **Presales** (a distinct *activity* track) · **Practice Lead** (buy-in). The six CE-delivery *roles* (FC/FSA/TC/TA/PM/EM) are a single **role-supplements page** of overlays, not six decks. The default sales/EA/exec-brief roles were dropped — the product doesn't serve them.
- **Setup track:** a standalone `setup.html` guided page (source: the team's `Setup-Guide.md` + the repo's `SETUP.md`), surfaced first via the topnav and the first role-grid card.
- **Standalone pages:** `sop-layer.html`, `setup.html`, and `role-supplements.html` all built from one bundled `render-doc-page.py` + per-page `.page.json` sidecar.
- **Visuals:** diagrams + (planned) annotated tool-session transcripts; an **audience-inclusive** topology SVG — *all* the audiences (practice lead, functional, technical, presales, + the delivery roles) and *multiple workspace scenarios* (client project, presales/POC, internal/IP, artifacts) sitting on the inherited substrate, flowing out to Dataverse, Azure DevOps, and client deliverables. Screenshot-verified, no Playwright.
- **The IP layer:** the SOPs got a prominent pillar **and** a standalone `sop-layer.html` deep-dive (three-source blend, authoring pipeline, HSO Overrides, the keep-current + expert-contribution model), linked from the landing band, the architecture page, and the SOP feature guide.
- **Grounding:** Phase 1 used parallel `Explore` agents over skills, SOPs, the wiki schema, and the scaffolding; a later workflow drafted the SOP deep-dive content blocks, each grounded in the real governance files.
- **Reader-first IA (added in iteration):** role tracks moved *above* the pillars; the pillars reframed as the reference library; guided `track-<role>.html` pages, a `glossary.html`, and a `faq.html` added as the reference layer, with glossary + FAQ surfaced in the top nav (see §11).

## 11. Organize for the reader — IA, and the reference pages it implies

The app-centric default makes the **product's structure** the organizing axis — pillars front and center, the primer and role tracks as entry aids. For an onboarding/reference pack that is the wrong axis, and it shows: readers ask *"why do I care about these pillars?"* because they're being asked to learn the *product's* shape before they get any value.

**Organize around the reader's journey instead.** The order that works for a learning pack is **Orient → Set up → Pick your role → Reference**:

1. **Orient** — the primer / "start here" (the paradigm, plus a plain *"you're not behind"* reassurance for newcomers: name the fear, say in one plain sentence what an LLM / the AI tool even is, and that every role uses it the same way).
2. **Set up** — the one-time setup track, for everyone.
3. **Pick your role** — the role tracks, placed *above* the pillars both on the page and in the nav.
4. **Reference** — the pillars/features, the standards-layer deep-dive, the glossary, and the FAQ: the shelf a reader reaches *from* their role, when they need it.

Reframe the pillars section to match: it's *"the reference library — what the product can do at each stage; your role track points you to the parts you need,"* not a section that has to justify itself. The honest answer to "why do I care about pillars?" becomes structural — *you don't, until your track sends you to one.* State the bridge explicitly: **pillar (a stage) → feature (a capability) → your role (who uses it) → the value (what changes).**

This implies three page types beyond decks and feature guides — all built from `render-doc-page.py` (`<name>.md` + `<name>.page.json`):

- **Guided role-track pages** (`track-<role>.html`). One per role, and the role-grid card leads *here*, not straight into a deck (a deck opened on its own is a dead-end you can't navigate back from). Each is a numbered path: **Set up (everyone) → Read your track (the deck) → Run a hands-on scenario → Your role overlay → What's next (a checklist).** It mostly *sequences* existing artifacts (setup, deck, practice scenario, role overlay) by linking to them rather than duplicating — keep it DRY. This turns "here's everything, good luck" into "do this, then this."
- **A glossary** (`glossary.html`). Group terms (e.g. *AI & tooling · the platform · the accelerator*) and write each as **"what it is / why it matters."** For a mixed-skill audience this is load-bearing — surface it in the **top nav**, not just the footer, because a newcomer hits an unfamiliar term mid-scroll, exactly when a footer link is hardest to find.
- **An FAQ** (`faq.html`). The logistics a newcomer needs: what the site is for, "have I fallen behind?" (no), tool/licensing eligibility (defer genuinely policy-dependent answers to a named owner — don't invent policy), POC/sandbox use, how to keep the product current, keeping IP internal, and **who to contact** (real names). For an accelerator, add a **"how do I propose a skill/SOP update?"** entry with two routes — submit a PR yourself, *or* have the assistant draft the proposal — and bundle a **copy-paste prompt** for the second route so a non-contributor can still surface a fix. Surface the FAQ in the nav too.

**Counts: write them open-ended.** When the product carries a count (skills, SOPs, features), write **"75+ skills", not "~59"** — and expect the number to appear in ~7 places: decks, `feature-metadata.json`, the landing hero stats, `index.html` / `architecture.html` prose, the generator's `HUB_NARRATIVES`, and page `.page.json` sidecars. A hardcoded count drifts the moment the product grows; the open-ended form survives it. (See the count gotcha in §9.)
