# Demo Data Fidelity — principles for a believable live demo

Companion to this skill's grounding guidance ("ground the demo in real environment data"). These are *narrative/fidelity* principles for the architect; the **seeding/config mechanics** live in the data/dev skills (`hso-dataverse-data`, `hso-dataverse-ui-config`, `hso-power-pages-config`) — reference them, don't script them here.

## 1. Numbers must be plausible for the demo *date*

A metric that's true in the abstract can be absurd on the calendar. "FPL agreement: 7,584 planned, **6 delivered**" reads fine in January — but if the demo is in **June**, "6 of 7,584 by mid-year" is not credible and undercuts the story.

- Anchor figures to **where the fiscal/calendar clock actually is** on demo day (mid-year ≈ ~50% of an annual plan).
- Prefer a **trajectory** over a single shocking number: a *recovery ramp* (actual climbing month over month toward plan) tells "the system caught it and the rep is closing the gap" — more credible *and* a better story than a flat near-zero.
- When you change the visual, **change the backing record too** (e.g. the agreement's delivered-units field) so a drill-in matches the chart. A dashboard that contradicts the record it links to breaks trust on the spot.

## 2. Time-anchored live state (timers, SLAs, "today" data)

Anything that renders **relative to now** must be set for the demo's date/time:
- **SLA timers / countdowns** (Case Response-By / Resolve-By) breach on a fixed clock — set them to be *counting down, not breached* at the demo start time, with headroom for the run. Re-anchor if the demo slot moves. (Mechanics: `hso-dataverse-ui-config` → SLA KPI timers.)
- "Past-due" invoices, "X days in stage", "due today" tasks — verify they still read correctly on demo day.
- **State the demo date/time assumption** in the clickpath build-note so whoever runs it knows what to refresh.

## 3. Persona casting — one persona, one job

Don't let a single persona do two contradictory jobs across acts.
- If "Candice" is the **email/Outlook** persona in Act 1, don't *also* make her the **portal/partner** persona in Act 3 — introduce a **distinct** persona (e.g. an independent MFG-rep at a partner agency) so each beat's identity is coherent and the security/role story is clean.
- Keep a **persona casting table** (name · role · which act/beat · login) and verify no persona is reused in a way that confuses the narrative.

## 4. Beat-value test — worked example (cut beats that don't serve the act's goal)

A beat earns its slot only if it advances *that act's* stated goal — re-confirm what each record/feature is actually *for*:
- **Stale pipeline / "awaiting an answer"** is a sales-follow-up problem → solved by the **stale-pipeline alert + an activity/task on the opp + the quote-feedback loop**. It is **not** a Case.
- A **Case** (quality complaint / claim / CAPA, 8D) is a *separate* post-sale process — keep it only if you're telling the quality-management story, and frame it as such, **not** as the fix for the pipeline beat.
- The tell: if a beat needs a different process model than the act's thesis, it's either mis-framed or cuttable. **End on the strongest beat**, and mark genuinely-separable beats (e.g. the Case) as ✂️ cut candidates with a one-line bridge.

## 5. Doc-sync discipline (so the script never drifts from the build)

- Keep **one canonical set** of demo artifacts (present-from script + deep-reference clickpath + outline). **Archive** superseded `_MR`/draft/consolidated variants into an `archive/` folder rather than leaving parallel near-duplicates that drift.
- Once the scripts are frozen for a run, log further environment/data changes in a **forward change-log** (e.g. `MR_Changes.md`, append-only dated entries) instead of re-editing the frozen scripts — fold into the scripts in a later batch.
- When you do reconcile, **grep for stale tokens** (old persona names, old numbers, old headings) across *all* canonical docs — merges silently re-introduce them.

## 6. Primary app & form selection — pin them before you write a single CLICK

Every navigable `CLICK:` / `SHOW:` resolves against a **model-driven app** (the `appid` in every deep-link) and a
**specific form**. Decide both up front or you'll re-key links and rehearse on the wrong screen.

- **Primary app.** Confirm which model-driven app the demo is presented from (e.g. "Sales Hub"). If it isn't
  known from context, **ask** — "Which app is this demo presented from?" — and record the answer (app name +
  `appid`) in the scenario block so the Master Script's tab map and every record link use it. If the demo needs an
  app that doesn't exist yet, **document the new app** (name, purpose, which tables it surfaces) as a build item
  for the data/config skills rather than silently assuming an OOB app.
- **Form selection.** When a beat opens a record, it lands on a form. **Default to the table's first main form**
  unless a beat needs a specific one — and it sometimes does: a control only renders on certain forms (e.g. an SLA
  KPI timer renders on *Case* / *Case – HSO* but not the quick/swarming/customer-card forms). When unsure whether
  the default form shows what the beat needs, **ask** ("which form should this open on?") or verify against the
  build, and then **name the form in the beat's `⚙ Setup` note**. Don't discover the wrong-form problem live.

## 7. Validate subgrids on the form — the related data that strengthens the beat

When you scope or review the **required data** for a beat, open the **primary form for that record** and read its
**subgrids and related tabs** — they tell you what related records the audience will expect to see populated, and
where a small amount of extra seed data turns a thin record into a credible one.

- For each subgrid/related tab on the form a beat opens, ask: *does the story benefit from a row here?* A quote with
  an empty **Quote Feedback** subgrid, an account with no **Open Invoices**, a case with zero **corrective-action
  tasks** — each reads as "demoware" the moment the presenter (or a skeptical buyer) scrolls.
- Seed only what **advances that beat's goal** (apply the beat-value test, §4) — don't fill every subgrid, fill the
  ones the narrative points at. Flag the related records you decide to seed as build items for the data skills.
- This is a *review/scoping* step for the architect; the **seeding mechanics** live in `hso-dataverse-data` /
  `hso-dataverse-ui-config`. (Subgrid discovery: `hso-dataverse-data-modeling` relationship queries.)

## 8. Demo date/time anchoring & demo-owned record stamping

**Capture the demo date and time as a first-class scenario input** (Step 2). Everything time-relative — SLA
timers, "days in stage", past-due invoices, "recovering toward plan" trajectories (§1, §2) — must be anchored to
that slot and **re-anchored if the slot moves**. State the assumption in the Master Script's `⚙ Setup` notes.

**Demo-owned record stamping (demo environments only).** If the project's `CLAUDE.md` records the CE environment's
**purpose as a demo environment**, every record seeded or repurposed for the demo must be **stamped as owned by a
specific demo** so a parallel build (another demo, another consultant) can't silently overwrite the seeded data:

- Two hidden fields on each table used for demo data (follow `hso-dataverse-naming-conventions`):
  - a **text** field tying the record to a specific demo/client — recommended `hso_demouse_text`
    (e.g. value `"Marmon Vision Demo 2026-06-12"`).
  - a **date** field for the demo date — recommended `hso_demodate_date`.
- Keep both **hidden on the form** (they're operational metadata, not part of the story) but set on every seeded
  record. Before repurposing an existing record, **check `hso_demouse_text`** — if it's stamped for a different
  demo, clone instead of overwrite.
- The field creation + hide is a data/config task (`hso-dataverse-data-modeling` to add the columns,
  `hso-dataverse-ui-config` to hide them); this skill's job is to **require the stamp** in the build spec and to
  confirm it's set on the records the Master Script depends on. If `CLAUDE.md` doesn't state an environment
  purpose, ask whether the target is a shared demo environment before seeding.
