---
name: aidevme-wiki-write-decision
layer: atomic
scope: core
description: |
  Scaffold an Architecture Decision Record (ADR) into agent/wiki/decisions/ with the next number,
  correct frontmatter, and the Context / Options / Decision / Consequences structure. Use when:
  (1) User says "write an ADR", "record this decision", "document why we chose X"
  (2) A load-bearing choice is made that future readers must not silently re-litigate
  Does NOT auto-supersede a prior ADR — it links forward and flags the human to flip the old status.
---

# aidevme-wiki-write-decision

ADRs are immutable decision history. This skill creates a new one correctly; the wiki linter checks
for contradictions across active ADRs but never auto-resolves them (that needs human judgement).

## Numbering & placement

`agent/wiki/decisions/NNNN-<kebab-title>.md`, `NNNN` = next zero-padded number after the highest
existing ADR in that folder.

## Frontmatter

```yaml
---
title: <short decision title>
type: decision
status: proposed | active | superseded
scope: product | project | personal
supersedes: <relative path to the ADR this replaces, if any>
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

## Body

```markdown
# ADR NNNN — <title>

## Context
<Forces at play; the problem/choice; constraints; prior ADRs referenced.>

## Options considered
1. <Option A> — pros / cons
2. <Option B> — pros / cons

## Decision
<The choice, stated plainly.>

## Consequences
<What becomes easier/harder; follow-on work; what this commits us to.>
```

## Rules

- One decision per ADR. Never edit a superseded ADR's decision — write a new ADR and set
  `supersedes:` (and, on approval, flip the old one's `status: superseded`).
- Append a `## [date] decision | ...` entry to `agent/log.md`.
- If the new decision contradicts an active ADR, STOP and surface it — do not silently overrule.

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-10 | aidevme | Ported from prior in-house skills and neutralised for the template. |
