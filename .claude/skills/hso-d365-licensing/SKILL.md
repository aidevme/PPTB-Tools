---
name: hso-d365-licensing
layer: atomic
scope: core
description: |
  Dynamics 365 and Power Platform licensing specialist — licence sizing for presales quotes, licence-impact review of implementation designs, per-engagement licensing baselines, anniversary / True-Up triage, and explaining Microsoft licensing rules (multiplexing, Team Members 15-table cap, Base/Attach mechanics, the Power Apps per-app 2026 retirement, the November 2025 EA tier elimination). See "## When to use" for the full trigger list. Does NOT cover contractual EA/CSP/MCA terms, product roadmap forecasting, or price negotiation.
---

# Dynamics 365 and Power Platform Licensing Skill

Licensing-specialist companion to [`hso-dataverse-architect`](../hso-dataverse-architect/SKILL.md). The architect skill is broad and high-level; this skill goes deep on a single subject: licensing.

## When to use

Use this skill when:

1. Sizing licences for a presales quote (which D365 base + attach SKUs, Power Platform tiers, capacity add-ons, Power Pages user packs, Copilot Credits)
2. Reviewing an implementation design for licence-impact (premium connectors, CE+F&O symmetric design, Dataverse-table additions to seeded apps, restricted-table flips, F&O role escalation)
3. Establishing a per-engagement licensing baseline at Solution Blueprint time
4. Triaging anniversary / True-Up findings (F&O enforcement, premium-connector surprises, capacity overruns)
5. Explaining Microsoft licensing rules — multiplexing, Team Members 15-table cap, Base/Attach mechanics, the Power Apps per-app 2026 retirement, the November 2025 EA tier elimination

Does NOT cover contractual EA/CSP/MCA terms (Microsoft's commercial team / customer's deal desk), product roadmap forecasting (use copilot-specific SOPs for AI-feature lifecycle), or the actual price negotiation (HSO advises on technical licence selection; contractual discount is Microsoft's).

## When the architect routes here

The architect skill explicitly defers to this skill for any licence-sensitive design choice. Common triggers:

| Architect spec touches | This skill provides |
|---|---|
| A persona's licence assignment | Base + Attach combination; Team Members eligibility (§5 of the SOP) |
| A premium connector | Per-user Premium vs Process licence decision rule (§8 of the SOP) |
| F&O writes for a CE-licensed user | Asymmetric-design pattern (§6); F&O role-escalation audit (§6.3) |
| A Dataverse table added to a seeded-tier app | The seeded→premium flip-trigger inventory (§7.4) |
| A Power Pages portal | Authenticated vs anonymous user-pack sizing (§12) |
| An AI Builder / Copilot Studio workload | Copilot Credit budgeting; AI Builder seeded-credit November 2026 cutoff (§14) |
| A capacity forecast | Database vs File vs Log tier sizing; the 20× Database-over-File price ratio (§10) |
| A presales quote | The §16 presales workshop format and licensing-baseline document |
| An implementation design review | The §17 implementation alignment gate |

## Authoritative Best Practices

**Read this SOP first for every task this skill handles:**

[`shared/dv/agent/wiki/sop/licensing/d365-and-power-platform-licensing-best-practices.md`](../../../shared/dv/agent/wiki/sop/licensing/d365-and-power-platform-licensing-best-practices.md) — the umbrella SOP. ~1,170 lines covering:

- §1 — The two source guides (D365 + Power Platform) and the monthly-cadence + landing-page-link discipline
- §2 — The five lifecycle gates (presales discover → quote → implementation blueprint → solution validation → pre-cutover)
- §3 — D365 license families quick reference (CE / F&O / cross-portfolio / Power Platform-adjacent SKUs)
- §4 — Base + Attach mechanics with the assign-attach-without-base hard-tenant enforcement gotcha
- §5 — Team Members SKU: 15-custom-table cap, the auto-include rule (Enterprise users get cross-app read), the CRUD use-rights table
- §6 — CE + F&O integrated scenarios: the cost trap, asymmetric design patterns A/B/C, the F&O anniversary audit obligation
- §7 — Power Apps Premium / per-app 2026 retirement / restricted-tables 10× cliff / seeded-tier flip triggers
- §8 — Power Automate Per-User / Process / Hosted Process decision rule
- §9 — Premium-connector governance (the design-review gate, not build-time discovery)
- §10 — Dataverse capacity (3 tiers, Dec 2025 default increases, April 2026 file-tier reclassification, CoE enforcement loop)
- §11 — Multiplexing CRUD test (indirect read ≠ licence; indirect create/update/delete = licence)
- §12 — Power Pages authenticated / anonymous user packs; contact ≠ licence rule
- §13 — Pointer to the Power BI SOP §12 + 2026 delta (P-SKU sunset for non-EA)
- §14 — Copilot Credits + AI Builder seeded-credit November 2026 cutoff + autonomous-agent consumption budgeting
- §15 — The November 2025 EA tier elimination and the discount caveat discipline
- §16 — The presales licensing workshop (two-hour format, inputs, outputs, sign-off)
- §17 — Implementation alignment gate (alignment questions, change-control note, pre-cutover verification)
- §18 — 8 anti-patterns with public-source incident citations ($1.8M True-Up, $120k seeded-flip, F&O blocked at financial close, etc.)
- §19 — Pre-quote / pre-design / pre-deploy / ongoing-operate checklists
- §20 — References

The SOP carries **six formal HSO Proposals** registered in [`hso-overrides.md`](../../../shared/dv/agent/wiki/system/hso-overrides.md) — read them before quoting any HSO position as established practice.

## Local reference snapshots — verbatim extracts

The two monthly Microsoft licensing PDFs are extracted to Markdown for grep-based navigation:

- [`shared/dv/agent/wiki/reference/licensing/dynamics-365-licensing-guide-2026-05.md`](../../../shared/dv/agent/wiki/reference/licensing/dynamics-365-licensing-guide-2026-05.md) — 72 pages, ~52k words, May 2026 edition
- [`shared/dv/agent/wiki/reference/licensing/power-platform-licensing-guide-2026-05.md`](../../../shared/dv/agent/wiki/reference/licensing/power-platform-licensing-guide-2026-05.md) — 26 pages, ~18k words, May 2026 edition
- [`shared/dv/agent/wiki/reference/licensing/source-pdfs/`](../../../shared/dv/agent/wiki/reference/licensing/source-pdfs/) — original PDFs preserved alongside

**Snapshot freshness discipline:** Microsoft republishes both guides monthly. The local `.md` files are perishable snapshots. Before quoting on any deal where licensing terms are load-bearing:

1. Download the current month's PDFs from the landing pages ([Dynamics 365](https://www.microsoft.com/en-us/licensing/product-licensing/dynamics365) and [Power Platform](https://www.microsoft.com/en-us/licensing/product-licensing/power-platform)) and drop them into `agent/_inbox/`.
2. Re-run [`agent/work/analysis/extract_licensing_pdfs.py`](../../../agent/work/analysis/extract_licensing_pdfs.py) — the script copies the PDFs into `source-pdfs/` and regenerates the `.md` extracts.
3. `git diff` the new snapshot against the prior month to spot changed numbers, footnote additions, removed SKUs.
4. If material changes are detected, update the SOP and re-run the §2 gates for in-flight engagements.

**Always link customer-facing artefacts to the landing page**, not a dated PDF URL — the dated URLs go stale within ~30 days per the §1 HSO proposal.

## Microsoft's authoritative URLs

When the local snapshot is insufficient or stale, fetch from these:

- [Dynamics 365 licensing landing page](https://www.microsoft.com/en-us/licensing/product-licensing/dynamics365)
- [Power Platform licensing landing page](https://www.microsoft.com/en-us/licensing/product-licensing/power-platform)
- [Dynamics 365 licensing documents index](https://www.microsoft.com/licensing/docs/view/Microsoft-Dynamics-365)
- [Multiplexing licensing guidance](https://www.microsoft.com/licensing/guidance/multiplexing) and [the multiplexing brief PDF](https://download.microsoft.com/download/3/D/4/3D42BDC2-6725-4B29-B75A-A5B04179958B/Licensing_Brief_PLT_Multiplexing.pdf)
- [Microsoft Learn — Premium tier connectors list](https://learn.microsoft.com/en-us/connectors/connector-reference/connector-reference-premium-connectors)
- [Microsoft Learn — Power Automate licensing FAQ](https://learn.microsoft.com/en-us/power-platform/admin/powerapps-flow-licensing-faq)
- [Microsoft Learn — Dataverse capacity-based storage details](https://learn.microsoft.com/en-us/power-platform/admin/capacity-storage)
- [Microsoft Learn — Team Members license overview](https://learn.microsoft.com/en-us/dynamics365/get-started/team-members-license)
- [Microsoft Learn — User Security Governance Tool (F&O)](https://learn.microsoft.com/en-us/dynamics365/fin-ops-core/dev-itpro/sysadmin/user-security-governance)
- [Microsoft Learn — Copilot Studio billing & licensing](https://learn.microsoft.com/en-us/microsoft-copilot-studio/billing-licensing)

For the full list (Microsoft official, FastTrack, independent analyst, MVP / community), see SOP §20.

## Independent licensing analysts to consult

Two stand out as cited-by-name across the SOP's research base — useful for confirming a position before quoting it to a customer:

- **Jukka Niiranen** — [licensing.guide](https://licensing.guide/) — dedicated Microsoft-licensing site; first-day commentary on every monthly PDF change (e.g. spotted the Jan 2026 per-app retirement on day one)
- **SAMexpert (Alexander Golev)** — [samexpert.com](https://samexpert.com/) — independent licensing analyst, ITAM Review's Microsoft Licensing Consultant of the Year 2021; deep coverage of Copilot Credits, AI cost split, EA / MCA contract structures

For the full analyst / MVP / community list, see SOP §20.

## Work product templates

When this skill is invoked, the deliverable is usually one of:

1. **Licensing baseline document** for an engagement — lives at `agent/wiki/system/licensing-baseline.md` per SOP §16.2. Carries the persona table, capacity table, connector inventory, discount assumption, anniversary timeline, open questions.
2. **Licensing review of a design spec** — a markdown note attached to the architect's spec calling out the licence implications per §17.1.
3. **Quote-time SKU + count list** — a markdown table feeding the deal desk's pricing tool. Always pairs list price with a discount range and the §15.3 caveat.
4. **Anniversary audit report** — for F&O engagements, the 90-days-before-anniversary [User Security Governance Tool](https://learn.microsoft.com/en-us/dynamics365/fin-ops-core/dev-itpro/sysadmin/user-security-governance) output + role-design recommendations.

For all four deliverables the SOP's checklist sections (§19.1 / §19.2 / §19.3 / §19.4) are the structure.

## Position boundaries

| In scope | Out of scope |
|---|---|
| Technical licence selection per persona / per workload | Contractual EA/CSP/MCA terms (Microsoft's commercial team owns this) |
| SKU + count list for presales quotes | Final price negotiation (deal desk + Microsoft) |
| Premium-connector inventory + licence-impact analysis | Building the actual flows (use `hso-powerautomate-writer`) |
| CE + F&O integration licence implications | Building the integration itself (use `hso-dataverse-architect` + relevant integration SOPs) |
| Power Pages user-pack sizing | Building the portal (use the `power-pages-*-best-practices.md` SOP family) |
| Copilot Credit budgeting at sizing time | Tuning Copilot agent design (use the `copilot-*-best-practices.md` SOP family) |
| Snapshot refresh + diff against last month | Authoring monthly licensing summaries for the wiki (re-run the extraction script + diff) |

## Routing back to architect

When a licensing analysis surfaces an architectural choice that needs design work — e.g. "we recommend an asymmetric CE-master design for these personas" — route back to [`hso-dataverse-architect`](../hso-dataverse-architect/SKILL.md) for the design spec. This skill identifies the licensing constraint; the architect designs around it.

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-11 | maciejnowicki | Ported from prior in-house reference skills and neutralised for the reusable template (dropped internal license header, stripped stray project tags). |
