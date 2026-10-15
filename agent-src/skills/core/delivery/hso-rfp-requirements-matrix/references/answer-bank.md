# Answer Bank

The reuse store of previously-confirmed requirement → verdict → comment answers.
It is the **accuracy engine** of this skill: rather than re-deriving every verdict from
scratch, the skill proposes answers that a consultant has already confirmed on prior RFPs.

## Critical: no client data in this shared skill

The bank that ships in this repo contains **only generic, product-level entries** —
de-identified, rephrased to neutral ERP capability statements, with **no client names,
no client-proprietary requirement text, no pricing**. The *real, growing* bank lives in a
**configured, non-committed location** (a project repo path or a SharePoint/OneDrive folder),
loaded at run time. Never commit a client's requirements or answers into this repo.

## Location (configured, not hardcoded)

Read the bank path from project config (`CLAUDE.md` / `CLAUDE.local.md`) under an
`Answer Bank Path` key, or ask the consultant. If none is set, run with the bundled generic
seed only and tell the consultant the bank is empty.

## Entry schema (JSONL — one entry per line)

```json
{"id":"gen-0001","requirement":"Solution supports multiple legal entities in a single instance","area":"General/Technical","verdict":"Standard","effort_band":0,"product":"D365 F&O core","comment":"Native multi-legal-entity support.","fit_score":"Above Average","source":"generic","confidence":"audited"}
```

| Field | Notes |
|---|---|
| `id` | stable key; `gen-*` for generic seed, project-prefixed for engagement entries |
| `requirement` | neutral capability statement (NOT a client's verbatim text in the shared seed) |
| `area` | canonical area hierarchy |
| `verdict` | one of the canonical verdicts (see [canonical-model.md](canonical-model.md)) |
| `effort_band` | 0–4 |
| `product` | product/ISV that satisfies it (from `hso-ip-reference`) |
| `comment` | justification narrative |
| `fit_score` | optional, for the dual-score archetype |
| `source` | `generic` \| `<project-id>` |
| `confidence` | `auto` \| `reviewed` \| `audited` |

## Matching is human-confirmed (never silent)

When classifying a new requirement, the skill finds candidate bank entries (text similarity)
and **proposes** the match — the consultant confirms "this requirement = that banked answer"
before the verdict/comment are reused. Unmatched requirements are LLM-drafted and flagged
`confidence: auto` for review. This prevents stale or wrong answers from propagating.

## Feeding the bank (look-beyond, feed-back)

Products/ISVs come catalog-first from `hso-ip-reference`; per run the consultant may supply
supplemental references (a SharePoint folder, a file list). Anything durable discovered that
way is **promoted back** — into the IP catalog (via `hso-ip-reference`'s
`Get-SharePointFolderListing.ps1`, which enumerates SharePoint over the Graph API) and/or into
the answer bank as new entries. Keep the two stores distinct: the catalog answers *what
product*; the bank answers *how we've answered this requirement before*.

> **Open governance question:** ownership and refresh cadence of the canonical taxonomy and
> the bank (vs. D365 release changes) is not yet decided. Until it is, keep new entries
> `confidence: reviewed` at most, and prefer human-confirmed matches.

## Generic seed

A small starter set of `source: generic` entries ships at
[`data/answer-bank.seed.jsonl`](data/answer-bank.seed.jsonl). Treat it as illustrative, not
authoritative — extend it from real (de-identified) experience in the configured bank, not here.
