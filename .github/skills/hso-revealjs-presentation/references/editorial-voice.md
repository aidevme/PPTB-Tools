# Editorial Voice & Factual Grounding — Reference

Working reference for slide content and speaker notes. Used by the [hso-revealjs-presentation](../SKILL.md) skill. Applies equally to slide bodies and speaker notes — speaker notes are exposed when a deck is exported to PDF, demoed in trainer mode, or distributed alongside the slides.

## Core principle

Every load-bearing claim has two parts:

1. A **status** — proposed, decided, recommended, considered, mandated, observed.
2. **Evidence** that the status is accurate.

The rule: the verb has to match the status, and the status has to trace to evidence. Decks fail when these come apart — when a verb claims commitment the evidence doesn't support, or when a fact appears with no source.

This is not a default-tentative register. A decided approach is described as decided when there is evidence the decision was made. The skill does not push softer language for its own sake; it pushes accurate language with provenance.

## Status vocabulary

Match the verb to the actual status of each claim.

| Status | Phrasing pattern | Evidence required |
|---|---|---|
| Decided / committed | "X is committed in [SOW]"; "[Client] has agreed to X" | SOW, approval record, prior decision artifact |
| Proposed | "the proposal contemplates X"; "the recommended approach is X" | The proposal itself + rationale on the slide |
| Recommended | "X is recommended because Y"; "HSO recommends X" | Stated rationale + evidence for the rationale |
| Under consideration | "X is under consideration; decision gate at [date]" | Open question, named owner, target date |
| Mandated by client | "X is required by [client policy]" | The client policy citation |
| Mandated externally | "X is required by [regulation / standard]" | The regulation citation |
| Observed | "the discovery materials show X"; "demo screenshot confirms X" | Discovery artifact citation |
| Reported by source | "[source] reports X" | The source document citation |

The fault to avoid: a claim that asserts a firmer status than the evidence supports.

## Banned phrases

Phrases that fail regardless of claim status. Replace with the recommended pattern. Extend this list per engagement as new offenders are identified.

### Colloquialisms / idioms

| Avoid | Replace with |
|---|---|
| "earns its keep" | "is justified by ..." / "delivers value through ..." |
| "stays honest" | "remains accurate" / "preserves transparency" |
| "lands hardest" | "is most consequential" |
| "the homework's done" | "discovery is already absorbed" |
| "rides [a roadmap / wave]" | "tracks [the roadmap]" / "depends on [the platform direction]" |
| "bets on" | "depends on" / "relies on" |
| "babysitting" | "extended support" / "ongoing oversight" |
| "hand-wave" | "general assurance" / "non-specific commitment" |
| "in the room" | "in this session" / "in the discussion" |
| "natural next chapter" | "directly relevant precedent" / "follows from" |
| "no VC pressure" | "privately held" / "no external investor cycle" |
| "lands in the cost slide" | "connects to the cost slide" |
| "we'll come back to that" | a pointer to the specific later slide |

### Marketing superlatives without evidence

A superlative is permitted only when the same slide substantiates it with a numeric basis or explicit comparison.

| Avoid | Replace with |
|---|---|
| "the single highest-value X" | "a high-priority X — [reason]" |
| "the only honest position" | "the most defensible position because [evidence]" |
| "the safe choice" | "the [evidence-supported] choice" |
| "every dollar of X is a dollar of Y" | "X compounds into Y because [mechanism]" |
| "best-in-class" | the actual benchmark + measurement |
| "industry-leading" | the actual rank + source |

### Conversational shortcuts

| Avoid | Replace with |
|---|---|
| "the cost model stays honest" | "the licensing model is segmented by [criterion]" |
| "every cost number [Person] shows you later" | "the cost model in Section [N]" |
| "not a compromise — a strategy" | direct statement of the trade-off and the basis for the choice |

### Outcome-presuming language (when the outcome is not yet decided)

Use these replacements only when the underlying status is "proposed" or "recommended" — not when commitment evidence exists.

| Avoid | Replace with |
|---|---|
| "we arrive ready to build" | "the planned workshops can be re-positioned from discovery to mobilization" |
| "the natural next chapter" | "directly relevant precedent" |
| "this is THE choice" | "this is the recommended approach because ..." |
| "we will deliver X" (no commitment evidence) | "the proposal contemplates X" |
| "HSO is the [adjective] choice" | "HSO's positioning on [criterion] is [evidence-grounded statement]" |

## Person references

Refer to client and HSO people by **role and division**, not first name, unless one of these conditions holds:

1. The person has been formally introduced earlier in the deck (named author block, org chart, sponsorship slide).
2. The person is the deck's named author / owner.
3. The reference is a documented direct quote attributed to a cited discovery artifact.

| Avoid | Replace with |
|---|---|
| "Chris's roadmap" | "the [Utility platform owner's] roadmap" |
| "Kelly's stated ask" | "[KITCO program management's] stated ask" |
| "Jason sees first" | "the [executive sponsor] sees first" |
| "every cost number Beth shows you later" | "the cost model in Section 3" |

This is generic professionalism. First-name references in client-facing material assume a familiarity that may not be reciprocal — even if the named person is internal HSO, the audience may not know them.

## Competitor neutrality

The deck never:

- Names a competitor.
- Uses coded references — "Big Four", "the incumbent", "another vendor", "most CRM proposals", "generic MSPs", "vendors who [...]", "any vendor who would [...]"
- Characterizes a competing approach as ignorant, lazy, or motivated by fee revenue.

Differentiation is asserted by describing what HSO does and why, with evidence — not by describing what others fail to do.

This rule applies to **speaker notes equally**. Notes are exposed in trainer mode, PDF export, deck distribution, and screen-shared demos.

Common failure patterns to remove:

- "A vendor who proposes X either [hasn't done their homework / is selling complexity for fee revenue]."
- "Most [vendor type] would answer this with a generic [bland line]; we answer it with [specific thing]."
- "Generic [collateral type] would look weak against a [Big Four] answer here."
- "[Competitor approach] doesn't require [our positioning]."

The substantive point in each of these is usually defensible. Strip the competitor framing and keep only the positive claim about HSO's approach.

## Self-asserted credentials

Permitted, but with attribution.

- ✅ "Per HSO 2025 corporate fact sheet — 400+ US employees"
- ✅ "Microsoft Partner of the Year 2025 — D365 Sales & Customer Insights"
- ❌ "30+ profitable years, no VC pressure" (uncited; conversational; conflates multiple facts)

When a single card cites two related facts (e.g., "35+ years in business" and "30+ profitable years"), confirm they are not internally inconsistent before publishing.

External self-asserted credentials (e.g., "Top-3 Microsoft partner globally") should be verified against a current, public HSO source before going on a slide. The presenter will be asked.

## Cross-document consistency

If the deck summarizes a long-form document — proposal markdown, design doc, SOW, prior approval record — the deck's commitments must not be firmer than the source.

- If the source says "considered", the deck cannot say "committed".
- If the source says "up to N weeks", the deck cannot say "N weeks".
- If the source flags an open question, the deck cannot present a closed answer.
- If the source says "approximately", the deck does not state the figure as exact.

This is the rule that catches deck/source-doc drift. The source documents are listed in the discovery answers (skill discovery question 7).

When the deck and source disagree, the resolution is one of:

1. Update the source document to match the (now firmer) deck commitment, with proper authorization.
2. Soften the deck to match the source.
3. Mark the slide explicitly as "[under consideration]" with the decision-gate target.

Do not leave the two in disagreement going into a session.

## Pre-delivery checklist

Run through this before declaring a deck done:

- [ ] **Numerical grounding** — every number, percentage, date, count, named entity, attributed quote on a slide traces to a discovery artifact, source document, or external public reference. The trace is in the speaker notes or in a deck-level source list.
- [ ] **Status verb fidelity** — every load-bearing claim's verb matches the actual status of the claim (decided / proposed / recommended / under consideration / mandated / observed).
- [ ] **Banned-phrase grep** — search the deck for the banned-phrase list above; replace each match.
- [ ] **Person references** — no first names except for formally introduced people, named authors, or quoted sources with citation.
- [ ] **Competitor neutrality** — no named or coded competitor references; no characterizations of competing approaches as ignorant, lazy, or fee-driven. Slide bodies AND speaker notes.
- [ ] **Credential attribution** — every self-asserted HSO credential traces to a public HSO source.
- [ ] **Cross-document consistency** — when summarizing a source document, no deck claim is firmer than the source.
- [ ] **Internal consistency** — no two claims on the same slide or related slides contradict each other (e.g., "35+ years" and "30+ profitable years" reconcile).
- [ ] **Speaker-notes hygiene** — no "trust" or "in the room" framings; no posture-revealing language; competitor neutrality applies.

The skill's audit scripts (when run) catch the mechanical issues — banned phrases, missing citations, source-doc drift on numerical claims. Judgment-call checks — particularly the verb-matches-status check — remain the writer's responsibility.

## Failure modes the audit cannot catch

The mechanical checks do not catch:

- **Absent claims** — facts that should have been cited but weren't.
- **Mis-attributed claims** — citation present but pointing to the wrong source.
- **Claims the writer should have made differently** — a different framing, a different rationale, a different recommendation.
- **Status that drifts mid-deck** — a topic discussed as proposed in one slide and as decided in another.

These require human review. The skill's structural and tone enforcement are necessary but not sufficient — the writer is still responsible for what the deck says.
