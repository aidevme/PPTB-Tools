# Claude Design Handoff Brief — Template

Copy this into `agent/work/design/<Feature>_ClaudeDesign_Brief.md`, fill the placeholders,
and use the **Opening Prompt** at the bottom as the first message in claude.ai/design.

The brief follows Claude Design's own "strong brief" shape — **goal, layout, content,
audience** — and adds the two things that make this an HSO handoff rather than a generic
one: the **as-is legacy context** (so it knows what we are replacing) and the **explicit
freedoms** (so it knows it is allowed — expected — to improve on it).

> **Golden rule:** give *context and intent*, not a pixel spec. We are migrating off a
> legacy D365 system. The aim is a better experience, not a faithful clone. If the brief
> reads like a list of "put field X here", you have over-constrained it.

---

## Brief frontmatter (project schema — `agent/schema.md`)

```yaml
---
title: "<Feature> — Claude Design Handoff Brief"
type: design
status: draft
scope: project
client: <client-id from CLAUDE.md, or "internal">
project: <project-id>
topics: []
people: []
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---
```

---

## 1. One-liner

> In one sentence: what is this feature and who is it for?

`<e.g. A quote-line editor that lets sales engineers build and price a multi-product quote
in one screen.>`

## 2. Goal & success criteria

- **Goal:** `<what the user is trying to achieve>`
- **What "great" looks like:** `<the experience outcome — e.g. "a first-time user prices a
  3-line quote in under a minute without training">`
- **What we are optimising for:** `<speed / clarity / fewer errors / fewer clicks / mobile
  usability — pick the 1–2 that matter most>`

## 3. Audience

| Persona | What they do here | Frequency | Device | Expertise |
|---------|-------------------|-----------|--------|-----------|
| `<role>` | `<task>` | `<daily / occasional>` | `<desktop / tablet / phone>` | `<novice / power user>` |

## 4. Jobs to be done

List the concrete tasks the user accomplishes, in priority order. These are *jobs*, not UI
elements.

1. `<e.g. Add a product to the quote and see the line total update live>`
2. `<...>`
3. `<...>`

## 5. The skeleton (what we have built)

What exists in the dev environment today — the functional bones Claude Design is dressing.

- **Data shape** (query Dataverse — do not guess; logical names + types + option-set
  labels):

  | Entity | Key fields (logical name · type · choices) | Relationship |
  |--------|--------------------------------------------|--------------|
  | `<hso_quote>` | `<hso_name (text)>`, `<hso_status (choice: Draft/Sent/Won/Lost)>` | `<1:N to hso_quoteline>` |
  | `<hso_quoteline>` | `<hso_qty (whole)>`, `<hso_price_amt (currency)>` | `<N:1 to hso_product>` |

- **Rough flow today:** `<describe the skeleton's current steps / the form layout as it
  stands>`
- **What is fixed vs open:** `<which parts of the data model are locked, which can still
  change if the UX needs it>`

## 6. As-is: the legacy D365 experience (context, NOT the target)

> Frame this as *the thing we are improving on.* Attach scrubbed screenshots.

- **How it works today:** `<short description of the current D365 screen/flow>`
- **What works:** `<keep these strengths>`
- **What hurts:** `<pain points — too many clicks, hidden actions, no mobile, etc.>`
- **Why we are replacing it:** `<the reason this is being redesigned>`

## 7. Constraints (the real boundaries)

Hard limits Claude Design must design within. Everything *not* listed here is fair game.

- **Target host:** model-driven app, embedded as a **PCF control** (virtual / React +
  **Fluent UI v9**). The design should feel native to a modern Dataverse app.
- **Design language:** Fluent v9 tokens / components where reasonable (we map to Fluent on
  the way back — see the return-loop reference).
- **Accessibility:** WCAG 2.1 AA (keyboard, contrast, screen-reader).
- **Performance / scale:** `<expected data volume, e.g. up to 200 lines per quote>`
- **Data the control can touch:** `<entities/fields from section 5; note anything it must
  NOT expose>`

## 8. Explicit freedoms (this is the point of the handoff)

State plainly that Claude Design is invited to:

- **Redesign the flow** — do not mirror the legacy screen; propose the experience you would
  build from scratch for this job.
- **Challenge our assumptions** — if the data model or our skeleton implies a clumsy UX, say
  so and propose the better shape.
- **Surface what we missed** — flows, states (loading / empty / error / success /
  disabled / no-permission), edge cases, validation, undo, bulk actions, progressive
  disclosure, keyboard shortcuts.
- **Propose, don't ask permission** — give us 2–3 variations on anything genuinely open, and
  recommend one.

## 9. What we want back

- The key screens and **every UI state** for each.
- A short list of **gaps / missing requirements** you found.
- **Where you diverged from the legacy D365 pattern, and why.**
- Runnable HTML (export or handoff-to-Claude-Code) so we can reconcile it into a PCF spec.

## 10. Asset checklist (attach these in the Claude Design project)

- [ ] Scrubbed screenshots of the as-is D365 screen(s) — `agent/raw/screenshots/<...>`
- [ ] Data-shape table / schema summary (section 5) — anonymised
- [ ] Anonymised sample data (a handful of representative rows)
- [ ] Brand / theme reference (or point Claude Design at the codebase / web-capture the live
      app)
- [ ] This brief

> **Data handling:** anonymise everything. No real client PII, account numbers, or
> financials. Confirm the engagement policy permits upload before attaching exports.

## 11. Open questions

- `<anything genuinely undecided you want Claude Design's view on>`

---

## Opening Prompt (paste this as the first message)

> Fill the `<...>` from the sections above, then paste into claude.ai/design after attaching
> the assets. Keep it intent-led.

```
I'm designing <Feature> for a modern Dataverse (Power Apps model-driven) app. It will ship
as an embedded PCF control using React + Fluent UI v9, so please lean on a clean, native
Fluent v9 look.

GOAL: <one-line goal>. We're optimising for <the 1–2 things that matter most>.

AUDIENCE: <persona(s)>, who <what they do here>, mostly on <device>, <novice/power user>.

THE JOBS TO BE DONE:
1. <job 1>
2. <job 2>
3. <job 3>

CONTENT / DATA: the screen works with <entities and key fields, plain-English>. I've
attached the data shape and some anonymised sample data.

CONTEXT: we're replacing an older Microsoft D365 screen (screenshots attached). It <what
hurts about it>. Please treat that screen as the thing we're improving on, NOT a template —
I do not want a clone.

WHAT I WANT FROM YOU:
- Design the experience you'd build from scratch for these jobs. Diverge from the legacy
  screen wherever you'd make it better, and tell me where and why.
- Tell me what we're missing — flows, states (loading / empty / error / success / disabled /
  no-permission), edge cases, validation, bulk actions, anything.
- Where a direction is genuinely open, give me 2–3 variations and recommend one.
- Cover accessibility (WCAG 2.1 AA) from the start.

Start with the primary screen and the core job, then we'll iterate together on the canvas.
```
