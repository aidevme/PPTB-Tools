---
name: hso-grill-architect
layer: orchestration
scope: core
description: Relentless one-question-at-a-time interview that grills a human Dataverse architect on a proposed feature design — surfaces conflicts with SOPs, naming conventions, existing schema, and prior digests, then captures the resolved decisions into an implementation-ready spec. Use when an architect says "grill me", "stress-test this design", "challenge my plan", "interview me about [feature]", or before any new feature spec is locked in.
---

# Grill Architect

Stress-test a proposed Dataverse design by interviewing the architect relentlessly — one question at a time, each with a recommended answer drawn from the relevant SOP, the live schema, or prior project decisions. Drive every fuzzy branch of the design tree to a resolved, sourced, scenario-tested answer, and write the result into the spec inline as decisions crystallize.

Adapted from Matt Pocock's `grill-with-docs`. The HSO version replaces a freeform `CONTEXT.md` glossary with the SOP library + naming conventions + live Dataverse schema, sinks decisions into the matching spec template, and delegates ADR authoring to `hso-wiki-write-decision`.

## When to use this skill

- Architect, PM, or developer-in-architect-mode says: "grill me", "stress-test this", "challenge my plan", "interview me about this feature", "help me think through this spec", "what am I missing?"
- Before any new feature spec is finalized — especially when the design is still fuzzy, contradictory, or under-discovered
- After ingesting discovery artifacts (`hso-wiki-ingest-discovery-artifact` / `hso-wiki-ingest-transcript`) when the design is still under-specified
- When two parts of a plan look inconsistent and the architect needs to reconcile them before writing the spec
- When the architect wants alignment with HSO best practices but hasn't read all the relevant umbrella SOPs

## When NOT to use this skill

- The spec is locked and code is being written — use `hso-requirements-author`, `hso-dataverse-architect`, or the relevant atomic skill instead
- The architect just needs an answer to a factual question — use `hso-wiki-query` or read the SOP directly
- Skill-library / wiki / tooling questions — use `hso-skill-creator`, `hso-wiki-update-topic`, etc.
- The user wants speed over rigor — say so explicitly and skip the grill

## Core rules — non-negotiable

1. **One question at a time.** Never batch. Wait for the architect's response before asking the next question. The cadence is the value.
2. **Always recommend an answer.** Open-ended questions waste the architect's time. Phrase every question as "the SOP / schema / prior digest implies X — agree, override, or refine?" and let them push back.
3. **Cite the source.** Every recommendation links to the SOP section, schema fact, ADR, or digest that produced it. No invented recommendations.
4. **Probe edge cases with concrete scenarios.** When a branch looks resolved, invent two specific failure scenarios and walk the architect through them. If the answer changes, the branch wasn't actually resolved — keep grilling.
5. **Surface conflicts the moment they appear.** Don't accumulate. Interrupt the flow. "Your last answer says X but the existing schema has Y. Which is it?"
6. **Update the spec inline.** As each decision crystallizes, write it into the draft spec. Don't batch capture — the audit trail is part of the value.
7. **Offer ADRs sparingly.** Only when hard-to-reverse + surprising-without-context + result-of-real-trade-off. If any of the three is missing, skip the ADR.
8. **Use canonical Dataverse vocabulary.** Sharpen fuzzy language — "the account" → which: Account table, parent Account record, the customer's User record? See `hso-dataverse-naming-conventions` for the vocabulary.

## Configuration

Read from `CLAUDE.md`: **Environment URL** (for schema queries) · **Project / Client identifier**
Read from `CLAUDE.local.md`: **Author Name** (for spec attribution)

If missing, ask the architect once at the start — don't repeatedly prompt.

## Workflow

### 1. Context bootstrap (before the first question)

- Ask the architect to describe the feature in one paragraph. Capture it verbatim into the draft spec's "Initial framing" section.
- Identify the feature type — which determines which umbrella SOPs and spec template apply:

| Feature type signal | Umbrella SOP to load first | Spec template |
|---|---|---|
| New tables / columns / relationships | `model-driven-apps/data-modeling-best-practices.md` | `data-modeling-spec-template.md` |
| Server-side business logic | `plugin-development/plugin-development.md` | `plugin-development-spec-template.md` |
| Custom action / function exposed via SDK | `custom-api/custom-api-best-practices.md` | `custom-api-spec-template.md` |
| Form layout, subgrids, timeline, ribbons | `model-driven-apps/form-configuration-best-practices.md` | `ui-config-spec-template.md` |
| Form scripts, ribbon scripts, HTML web resources | `webresource-development/webresource-best-practices.md` | `formscript-development-spec-template.md` |
| PCF control | (consult `hso-pcf-control-development` references) | `pcf-control-spec-template.md` |
| Power Automate cloud flow | `power-automate/power-automate-cloud-flow-best-practices.md` | `powerautomate-flow-spec-template.md` |
| Security role / FLS / BU strategy | `security/security-best-practices.md` | `security-role-spec-template.md` |
| Portal-fronted feature | `power-pages/power-pages-best-practices.md` | *(no template; capture in feature spec)* |
| Analytics / BI / lakehouse | `analytics-integration/synapse-fabric-link-best-practices.md` | *(no template; capture in feature spec)* |
| Solution architecture | `dataverse-solutions/dataverse-solutions-best-practices.md` | *(no template; capture in feature spec)* |

- Read all relevant digests in `agent/wiki/digests/` (transcripts, discovery artifacts, meeting summaries) — these carry the requirements the architect may have forgotten.
- If tables/columns/relationships are in scope, query the live schema via `hso-dataverse-data` to know what already exists. Conflicts between the proposed design and live schema must be surfaced during the grill, not after.
- Skim `agent/work/specs/` for related prior specs — they may contain prior decisions to honor or override.

### 2. Build the question tree

Each umbrella SOP starts with a decision matrix — use it as the root of the tree. Each decision matrix branch becomes a question node. See [references/decision-trees.md](references/decision-trees.md) for the seed trees per feature type.

Order nodes by dependency: choices that constrain later choices come first. Example for a new-feature spec involving a table:

1. OOB-vs-custom (constrains everything downstream)
2. Table type + ownership (constrains relationship cascades, security)
3. Primary name + alternate keys (constrains integration)
4. Relationships + cascade behavior (constrains plugin design)
5. Choices (must be global per HSO standard)
6. Server-side logic — plugin vs Custom API vs Power Automate vs Workflow (constrains deployment pipeline)
7. UI — form layout, views, dashboards
8. Security — role + FLS
9. ALM — solution placement, segmentation
10. Operational concerns — performance budget, monitoring, telemetry

### 3. Grill loop

For each unresolved node, repeat:

1. **Recall** what the SOPs / schema / digests imply for this node.
2. **Phrase the question** naming the choice + recommending the SOP-aligned answer. See [references/grilling-patterns.md](references/grilling-patterns.md) for question phrasings.
3. **Wait for the response.** Never advance until the architect responds.
4. **Classify the response:**
   - **Accepted as recommended** → record in the spec, move to dependent nodes.
   - **Overridden with a reason** → record both the decision AND the rationale verbatim. The rationale matters more than the choice itself for future readers.
   - **Overridden without a reason** → push back once. "Help me understand — the SOP recommends X because of Y. What's the constraint that makes Y not apply here?" If still overridden, record the override and move on; flag for ADR review.
   - **Contradicts an earlier decision** → freeze the dependent nodes, surface the conflict, resolve before continuing.
   - **Vague / I-don't-know** → probe with a concrete scenario. If still vague, mark the node `OPEN` and continue with a placeholder, but never silently accept ambiguity.
5. **Scenario probe** before declaring the node resolved — invent two concrete edge cases (high-volume, concurrent edit, permission denied, offline, mid-process cancel, parent deletion) and walk the architect through each. If the answer changes, the node wasn't resolved.

### 4. Inline spec capture

- For each resolved decision, write it into the draft spec using the matching template from `shared/dv/agent/wiki/reference/*-spec-template.md`.
- Capture the architect's rationale verbatim in a "Decisions" section. Don't paraphrase; future readers need the original voice.
- If a later decision invalidates an earlier section of the spec, **strike through** the invalidated text (`~~like this~~`) rather than silently overwriting. The audit trail of overturned positions is part of the value.
- After every 3–5 resolved nodes, summarize "where we are" in two sentences so the architect can confirm direction before deeper branches.

### 5. Offer ADR (sparingly)

When a resolved decision meets **all three** criteria, propose an ADR:

1. **Hard-to-reverse** — schema-shaping, public-API-shaping, security-perimeter-shaping, or anything that locks a customer-visible contract.
2. **Surprising without context** — a future maintainer will ask "why did they do it this way?"
3. **Result of a real trade-off** — genuine alternatives existed, and the architect chose one for stated reasons (not because the SOP told them to — that's not a trade-off, that's compliance).

If all three: delegate to `hso-wiki-write-decision`. If any is missing: skip — the decision lives in the spec, not in an ADR. ADR fatigue is real.

### 6. Exit conditions

The grill ends when **any** of:

- All branches in the question tree are resolved AND the spec compiles (every template section is non-empty or explicitly marked N/A).
- The architect signals alignment ("we're good", "I've got what I need", "let's stop") — exit gracefully, write a closing summary listing OPEN items.
- The conversation reveals the feature should not be built (kill-it-or-defer-it surfaces in roughly 10% of grillings — record the reasoning and stop).

**Semantic-research refusal (hard gate).** Sign-off is refused while any net-new custom table in the design lacks a **Semantic Research Summary** (from `hso-semantic-data-modeling`) naming the CDM/OOB candidate it rejected and why. A missing summary means the OOB-vs-custom node is `OPEN` by definition — no matter how confidently the architect answered it — and an `OPEN` OOB-vs-custom node blocks the first exit condition: run the research (or have the architect run it) before the grill can conclude with sign-off. A graceful early exit is still allowed, but the closing summary must list the unresearched table as `OPEN` and state that the DAG is **not signed**. Custom-by-default is precisely the failure this gate kills: a skipped research stage reads as "no conflict found" downstream, and nobody ever decided.

On exit, write a closing message that lists:
- Resolved decisions (count)
- Open items needing follow-up (with owners if specified)
- ADRs proposed (with status: drafted, deferred, declined)
- Next skill to invoke (`hso-dataverse-architect` to author the full design doc + slice DAG, etc.)

When the spec carries a slice register with an `ADO build type` column (`adoProjection`,
[ADR 0048](../../../agent/wiki/decisions/0048-build-slices-project-1-1-into-ado-build-management.md)),
the projection is part of what sign-off approves: the delivery pipeline's Stage-0 will
batch-create one Build Management work item per slice from it, and implementation is gated
on those items existing. Challenge projection rows that look wrong (type, `relatedTargets`,
an unprojected slice that is actually actioned work) **during** the grill, not after.

**Slice context-budget dispositions (architect rule 9).** Run `Validate-SpecJson.ps1` during the
grill and walk every rule-9 flag with the architect: each flagged slice is either **split** along a
verification-concern seam (the gate, the load, or the walk moves out — never one table's columns
across writers) or keeps a recorded `budgetAccepted: "<reason>"` the grill has actually challenged
("single plugin assembly, nothing else rides in it" is a valid reason; "it fits, probably" is not).
Silence is not a valid state — the delivery pipeline's `-Signed` Stage-0 gate refuses a flagged,
undispositioned slice, so an unresolved flag at sign-off means the spec is not ready. Evidence base:
round-3 (2026-08-15) — every multi-concern slice over ~105 executor calls compacted mid-build; every
single-concern slice stayed intact.

## Companion skills

| Skill | Used for |
|---|---|
| `hso-wiki-query` | Context bootstrap — find prior decisions and digests |
| `hso-requirements-author` | Authors the upstream requirements brief the design grills against |
| `hso-dataverse-architect` | Consumes the finished spec and authors the full design doc |
| `hso-dataverse-data` | Live schema queries during conflict-checking |
| `hso-dataverse-naming-conventions` | Canonical vocabulary; consulted when sharpening fuzzy terms |
| `hso-wiki-write-decision` | Invoked when a resolved decision qualifies for an ADR |
| `hso-semantic-data-modeling` | Pre-research for new-table decisions (CDM, industry standards) — invoke during context bootstrap if a new table is in scope |

## Critical rules

### DO
- Ask exactly one question per turn
- Recommend an answer for every question, sourced from a specific SOP section / schema fact / digest
- Cross-reference against `agent/wiki/digests/` AND the live schema before recommending
- Use canonical Dataverse vocabulary (`hso-dataverse-naming-conventions`)
- Surface SOP / schema / prior-decision conflicts the instant they appear
- Write decisions into the spec inline, not at the end
- Probe with concrete scenarios, not abstract follow-ups
- Strike through (don't delete) invalidated decisions to preserve the audit trail

### DO NOT
- Sign off a design in which a net-new custom table has no Semantic Research Summary — an unresearched OOB-vs-custom node is `OPEN`, not resolved (Exit conditions, semantic-research refusal)
- Batch questions ("here are five things to think about…")
- Ask open-ended questions without a recommended answer
- Let vague terms slide — sharpen them on the spot
- Silently override prior decisions — strike-through with explanation
- Offer ADRs for decisions that don't meet all three criteria
- Continue grilling after the architect signals "we're good" — exit gracefully
- Fabricate SOP citations — if you can't find the source, say so and degrade the recommendation to "my reading is X — verify"
- Treat the spec as a draft that gets cleaned up later; the inline writes ARE the deliverable

## References

- [references/decision-trees.md](references/decision-trees.md) — seed question trees per feature type, with each node linked to its source SOP section
- [references/grilling-patterns.md](references/grilling-patterns.md) — question-phrasing templates, scenario-probe library, conflict-handling playbook

## Source

Adapted from Matt Pocock's `grill-with-docs` (https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md). The original's "interview about a plan, update CONTEXT.md + ADRs inline" pattern is preserved; the HSO version replaces the generic glossary/codebase-exploration model with SOP-anchored decision trees, live Dataverse schema cross-checks, and inline writes into a typed spec template.

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
