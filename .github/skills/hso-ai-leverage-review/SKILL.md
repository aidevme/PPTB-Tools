---
name: hso-ai-leverage-review
layer: orchestration
scope: core
description: |
  Review a process narrative — a day-in-the-life, a role workflow, a transcript/discovery digest, or a Requirements Brief/spec — for where AI *should and could* be applied, and emit a scored AI-Leverage Register. Every step gets BOTH a process-improvement note and an AI-feasibility rating (unless the source already prescribes a specific solution). Each candidate is mapped to an existing HSO skill/SOP (automate now), a skill to extend, or a gap (candidate new skill/agent), then ranked by leverage. Feeds hso-estimate-from-content (PT), hso-requirements-author (gated acceptance criteria), and hso-wiki-write-decision (gaps → ADR). Use for "where can we use AI here", "find automation opportunities", "AI feasibility review", "review this day-in-the-life / process / spec for AI leverage". Does NOT build anything or write the design — it scores opportunity and routes it.
---

# AI-Leverage Review

Turn a description of how work is done today into a ranked, evidence-backed answer to two questions, per step: **how could this process be improved?** and **how feasible is AI/automation here — and how much of it should a human still own?**

This operationalizes the "effort made visible" principle from the AI-Augmented Delivery methodology (see the [digest](../../../agent/wiki/digests/2026-06-25-ai-augmented-delivery.md)): every routine pattern becomes a *quantified automation candidate*, and every candidate carries an explicit **human-on-the-loop** checkpoint. Governed by [ADR 0035](../../../agent/wiki/decisions/0035-ai-leverage-review-and-spec-time-disposition.md).

## When to use this skill

- A **day-in-the-life / role workflow / process narrative** needs to be mined for automation opportunities (discovery mode).
- A **Requirements Brief or design spec** needs each requirement tagged with an AI-delivery disposition and gated acceptance criteria (design mode).
- A **completed deliverable/build** needs an audit — did we apply the leverage we identified (audit mode).
- Triggers: "where can we use AI here", "find automation opportunities / candidates", "AI feasibility review", "how much of this should AI do", "review this process/spec for AI leverage".

## When NOT to use

- To *build* the automation — that's the executor skills (`hso-powerautomate-writer`, `hso-plugin-development`, agent build, etc.).
- To *design* the Dataverse solution — that's `hso-dataverse-architect`.
- To *estimate* — this skill hands ranked candidates to `hso-estimate-from-content`; it does not price them itself.
- As a system-state snapshot of an existing environment — that's `hso-analyze-system-review`.

## Configuration

Read from `CLAUDE.local.md`: **Author Name** (for the register's `people:` / attribution). If missing, ask.

## Inputs

One of: a narrative/transcript, a digest under `agent/wiki/digests/`, a Requirements Brief/spec under `agent/work/specs/`, or a completed deliverable. If the source is a raw transcript/document not yet ingested, route it through `hso-wiki-ingest-transcript` / `hso-wiki-ingest-discovery-artifact` first, then review the digest.

## The rubric (score every step)

For each activity/step, score five factors, then derive the disposition, feasibility, and a process-improvement note.

| Factor | Question | Scale |
|---|---|---|
| **Frequency / volume** | How often / at what volume does this run? | low · med · high |
| **Determinism** | Rule-based, or judgment/relationship? | rule → judgment |
| **Machine-readability** | Is the input already digital / MCP-reachable? | yes · partial · no |
| **Review cost** | How cheap is it to verify AI output? | cheap · moderate · expensive |
| **Risk / blast radius** | Regulatory, financial, irreversible? | low · med · high |

Derive:

- **AI-disposition** (how much AI, how much human):
  - `agent-built` — AI produces it; a human approves before it takes effect. *Must* name the human checkpoint.
  - `agent-assisted` — AI drafts; a human completes/decides.
  - `human-only` — judgment, relationship, or accountability that stays with a person.
- **AI-feasibility** — High / Medium / Low + a one-line why (drives sequencing, not the disposition).
- **Process-improvement note** — the non-AI improvement (dedupe a handoff, remove a re-key, make a source machine-readable). **Always present**, because AI feasibility is not the only lever.

> **The always-both rule.** For every step, output BOTH the process-improvement note AND the AI-feasibility rating. Collapse to a single recommendation ONLY when the source is *very specific* and already prescribes a concrete solution for that step — otherwise you will silently drop one of the two levers the review exists to surface.

## Leverage score & ranking

`leverage ≈ (frequency × effort_saved) ÷ (review_cost + risk)`. Rank candidates; surface a top-N shortlist. Say explicitly what fell below the cut — a silent top-N reads as "nothing else qualified."

## Mapping to the catalog

Every ranked candidate maps to exactly one of:

- **Automate now** → names the existing skill/SOP that already does it (e.g. `hso-powerautomate-writer`, `hso-dataverse-sample-data`, `hso-learning-pack`). Read `claude-code/skills/INDEX.md` for the current catalog.
- **Extend** → an existing skill that *nearly* covers it, with the one-line gap.
- **Gap** → no skill/agent covers it → a candidate new skill or **custom agent** (task-agent or a distributor/router, per the methodology's agent taxonomy). Route material gaps to `hso-wiki-write-decision`.

## Workflow

1. **Verify author config.** Do not proceed without an Author Name.
2. **Identify mode** from the input: discovery (narrative/digest), design (brief/spec), or audit (deliverable).
3. **Segment into steps.** Break the source into discrete activities/requirements. Preserve source order and cite the source line/section for each.
4. **Score each step** against the rubric. Fill BOTH columns (process-improvement + AI-feasibility) per the always-both rule.
5. **Rank** by leverage; pick the shortlist; state the cut.
6. **Map** each shortlisted candidate to Automate-now / Extend / Gap against `claude-code/skills/INDEX.md` and the SOP set.
7. **Mode-specific output:**
   - **Discovery** → write the AI-Leverage Register to `agent/work/analysis/[subject]-ai-leverage-register.md`.
   - **Design** → additionally emit, per requirement, an **AI-disposition + gated acceptance-criterion suggestion** for `hso-requirements-author` to fold into the brief (see that skill's "AI-delivery disposition pass"). Never rewrite the design — suggest the disposition and the human-on-the-loop AC only.
   - **Audit** → diff the deliverable against a prior register (or reconstruct expected leverage) and report applied / skipped / regressed.
8. **Hand off.** Top candidates → `hso-estimate-from-content` (PT). Gaps worth building → `hso-wiki-write-decision` (ADR). Design-mode dispositions → `hso-requirements-author`.
9. **Add a log fragment** under `agent/log/` (`## [YYYY-MM-DD] analysis | <subject> | AI-leverage register` — ADR 0062; append to `agent/log.md` only in pre-0062 repos). Do not hand-edit `index.md` (generated).

## Output artifact — register shape

```markdown
# AI-Leverage Register — <subject>  (<mode>, <date>)

| # | Step (source cite) | Freq | Det. | Data | Review | Risk | Disposition | AI-feasibility | Process-improvement note | Maps to |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Re-key vendor master from PDF (§2) | high | rule | partial | cheap | low | agent-built (consultant approves exceptions) | High — OCR+match is proven | Kill the re-key; capture at source | hso-dataverse-data (extend: PDF intake) |
| 2 | Decide credit-hold exception (§5) | med | judgment | yes | — | high | human-only | Low — accountability | Give the human a scored summary | — (gap: decision-support agent) |

**Top candidates (ranked):** …   **Below the cut (stated):** …
**Handoffs:** estimate → …; ADRs → …; dispositions → …
```

## Critical rules

### DO
- ✅ Output BOTH a process-improvement note and an AI-feasibility rating for every step (the always-both rule).
- ✅ Give every `agent-built` disposition a named **human-on-the-loop** checkpoint.
- ✅ Cite the source step/line for each register row.
- ✅ State what fell below the ranking cut.
- ✅ Map every shortlisted candidate to Automate-now / Extend / Gap against the live `INDEX.md`.

### DO NOT
- ❌ Build, configure, design, or price anything — score and route only.
- ❌ Collapse to a single recommendation unless the source already prescribes a specific solution for that step.
- ❌ Rewrite a spec's design in design mode — suggest disposition + AC, nothing more.
- ❌ Invent a leverage score without the rubric factors behind it.
- ❌ Hand-edit `index.md` (linter-owned).

## Related
- [ADR 0035](../../../agent/wiki/decisions/0035-ai-leverage-review-and-spec-time-disposition.md) — the decision this skill implements; the always-both rule and human-on-the-loop-at-spec-time.
- [AI-Augmented Delivery digest](../../../agent/wiki/digests/2026-06-25-ai-augmented-delivery.md) — the methodology this skill operationalizes.
- `hso-estimate-from-content` — prices the ranked candidates.
- `hso-requirements-author` — consumes design-mode dispositions as gated acceptance criteria.
- `hso-wiki-write-decision` — records material gaps (new skill / custom agent) as ADRs.
- `hso-analyze-system-review` — sibling analysis skill for system *state* (this one reviews *process*).

## Changelog
See sibling **[CHANGELOG.md](CHANGELOG.md)** (ADR 0021).
