---
name: aidevme-wiki-query
layer: atomic
scope: core
description: |
  Answer natural-language questions about project or product knowledge by searching `agent/wiki/`, `agent/work/`, and (in consuming repos) every inherited tier's `shared/<slug>/agent/wiki/`. Returns a cited answer — every claim links to its source file; paraphrased claims from `summary-only` chains are marked as such. Use for "what do we know about X?", "where is X documented?", "who decided X?", "search the wiki", or any project-history / ADR / topic / digest lookup. Never fabricates — says so explicitly when the wiki has no answer.
---

# HSO Wiki Query

Answer questions from the wiki with explicit citations. This is the primary read-path for the hybrid `agent/` wiki — everything else writes, this one reads.

## What this skill is good for

- "What do we know about cutover for Client X?"
- "Why did we choose polymorphic lookups for the intake table?"
- "Has anyone documented the naming convention for Power Automate flows?"
- "When did we decide to use staged migration instead of big-bang?"
- "Which ADR covers the publisher prefix policy?"
- "Show me every digest that mentions data migration from the last 3 months"

## What this skill is NOT for

- Questions that need real-time data (ADO work item status, Dataverse metadata, live metrics) — use a dedicated skill for those
- Questions that require reasoning the wiki doesn't contain (speculation about future architecture) — the wiki is a memory, not an oracle
- Code review or implementation questions — use the relevant code skills

## Configuration

None required. The skill reads from `agent/` at the current repo and from **every** inherited tier under `shared/<slug>/agent/wiki/` — the `wiki/` subtree only, never the inherited `work/`, `raw/`, or `_inbox/`.

## Workflow

### 1. Identify the search scope

**Enumerate the tiers; never hardcode `shared/dv`.** A repo may inherit several tiers, and as of
[ADR 0061](../../../agent/wiki/decisions/0061-tier-precedence-specificity-plus-binding.md) they are
not peers — a governance (program) tier outranks the product tier. Get the list, in rank order,
from the shared helper rather than guessing from folder names:

```powershell
. "<skills-root>/aidevme-shared-scripts/scripts/Wiki-Tiers.ps1"
$tiers = @(Resolve-WikiTiers -RepoRoot $repoRoot -IncludeLocal)
```

Each entry is `{ slug, class, rank, path, wikiPath, real, registryPath, registryFormat, manifest }`,
ordered **ascending by rank = descending by specificity**:

| Rank | Class | What it is |
|---|---|---|
| 0 | `project` (or `product` in Forge-USA itself) | the local `agent/` — this repo's own wiki |
| 100, 110, … | `governance` | a program/standards tier, inherited read-only. **Outranks product tiers.** |
| 200, 210, … | `product` | `dv` (Forge), `fo`, `pp`, … — HSO methodology per Microsoft product |

Then:

- **Walk the local `agent/`** — always. Product tier in `Forge-USA`, project tier in a consuming repo, personal tier in a personal repo.
- **Walk each tier's `wikiPath`** — the `wiki/` subtree **only**. The inherited `agent/work/`, `agent/raw/`, and `agent/_inbox/` are that tier's internal workshop (testing, grading, scratch) and are **never read cross-tier**: per [ADR 0038](../../../agent/wiki/decisions/0038-published-surface-boundary-and-release-governance.md) / schema invariant #18, only `agent/wiki/` crosses the tier boundary. This is how a consuming repo queries product- and program-level knowledge without leaving its own repo.
- **Inherited tiers are read-only** (schema invariant #15). Read them, cite them, propose local actions from them — never write to them.
- **Do NOT walk `raw/` directly** for query purposes. Digests summarise raw material; queries should hit the digest first and only drop to raw when the digest's working summary is insufficient.

If the helper is unavailable (an old clone), fall back to walking each `shared/*/agent/wiki/` that
exists, in alphabetical order — degraded but not wrong. Do not fall back to assuming `dv` is the
only tier.

### 2. Start from `index.md`

Read the `index.md` at each tree root. This is the curated entry point: categories, pages, one-line summaries. It's the fastest way to orient before keyword search.

From `index.md`, identify candidate categories relevant to the query:

- Question about a decision → **decisions** section
- Question about HSO methodology / "how do we…" → **sop** section (authoritative HSO-authored content); the matching **topic** anchor page is a useful secondary starting point to discover related SOPs, references, ADRs, and skills
- Question about a specific stakeholder → **people** section
- Question about a meeting or document → **digests** section
- Question about external reference material (Microsoft/vendor) → **reference** section
- Question about current state (schema, environment, stack) → **system** section
- "Where should I look for everything on subject X?" → **topics** section (anchors surface all relevant sources from one page)

### 3. Grep for keyword candidates

Extract keywords from the query (proper nouns, domain terms, dates, decision words). Use the Grep tool to find files in `wiki/` and `work/` matching those keywords. Favour content matches over filename matches.

Rank candidates by:

1. **Exact phrase match** > word match > partial match
2. **Recency** — newer `updated:` beats older (use frontmatter, not file mtime)
3. **Status** — `status: active` beats `status: superseded` beats `status: archived`
4. **Rank** — where tiers disagree, the **lower rank number wins** (project ▸ governance ▸ product), because that is the same precedence the architect designs under. Prefer local/project hits for questions about a specific engagement and product-tier hits for questions about HSO methodology, but when two tiers genuinely conflict, lead with the more specific one and **say which tier it came from**.

### 4. Read the top 3-5 candidates

Don't read everything. Read the 3-5 most relevant candidates in full, including their frontmatter. Pay attention to:

- `type:` — is this an ADR, a topic, a digest, a person page?
- `status:` — if `superseded`, follow the `supersedes:` chain to find the current version
- `sources:` — for digests, note the raw files (and fidelity if any source is a capture)
- `topics:` / `people:` — cross-references that may surface additional relevant pages
- `created:` / `updated:` — for time-sensitive questions

If a candidate points to another page via `supersedes:`, `sources:`, or an inline link that looks load-bearing, follow the link and read that too.

**Reading a topic (anchor page):** topics in `wiki/topics/` are navigation, not content (per [ADR 0005](../../../agent/wiki/decisions/0005-topics-are-anchors.md)). When you land on a topic page, the short orientation paragraph tells you what the subject is; the link sections (SOPs, Reference, Decisions, Digests, Skills, External) tell you where the authoritative content lives. **Do not treat the anchor body as the answer source.** Follow the links to SOPs and references and synthesise the answer from those — not from the anchor's orientation paragraph, which is by design too thin to answer a real question.

### 5. Check fidelity of source chains

For any claim you're about to make in the answer, trace its source chain:

- Claim came from a topic page → topic cites which digests? Read them.
- Claim came from a digest → digest cites which captures or raw files? Check the `fidelity:` of each capture in the chain.
- If any link in the chain is `fidelity: summary-only`, the claim cannot be stated as a verbatim quote — only as paraphrased knowledge.
- If the chain is `fidelity: excerpts`, verbatim quoting is OK only for the quoted sections the capture preserves.
- If the chain is `fidelity: full-copy`, verbatim quoting is OK.

The answer should make this implicit most of the time — just don't use quote marks around paraphrased content — but if the question explicitly asks for wording ("what exactly did the client say?"), surface the fidelity limitation explicitly.

### 6. Synthesise the answer

Write a direct answer to the user's question. Structure:

1. **Lead with the answer** in one or two sentences.
2. **Support with cited claims** — every non-obvious statement includes a citation.
3. **Note gaps or uncertainty** — if the wiki doesn't fully cover the question, say what's missing.
4. **Point to follow-up reading** — the most relevant 1-3 files the user should open for the full picture.

**Citation format:** use inline markdown links, not footnotes:

```
The staged cutover approach was adopted in [ADR 0007](../../../agent/wiki/decisions/0007-staged-cutover.md) because the parallel-run validation window needed to be at least 72 hours for the Client X intake flow ([digest 2026-03-28](../../../agent/wiki/digests/2026-03-28_cutover-workshop.md)).
```

This keeps citations scannable and clickable in the IDE.

### 7. Say "I don't know" when appropriate

If the wiki doesn't contain a clear answer, say so. Examples:

- "No ADR covers this decision yet. The closest is [ADR 0005](...) which touches on the topic but doesn't resolve it."
- "The wiki has no anchor page for 'data retention' in `wiki/topics/`. Two digests mention it in passing: [...] and [...]. Consider running `aidevme-wiki-update-topic` in synthesis mode to create an anchor that links to them."
- "No digest references Client X's cutover plan directly. The only related content is an older ADR from the previous engagement."

**Never fabricate.** If you're not sure, check again or ask the user for clarification. Made-up answers are worse than "I don't know" in a knowledge-base context.

### 8. Suggest next actions when relevant

If the query exposes a gap, suggest a concrete follow-up:

- "This anchor has no links yet under SOPs or Reference. Run `aidevme-wiki-update-topic cutover --synthesis` to scan `wiki/sop/` and `wiki/reference/` for related material to propose."
- "The decision is recorded in an implementation note but not in an ADR. Consider promoting it with `aidevme-wiki-write-decision`."
- "The source transcript is still in `_inbox/`. Run `aidevme-wiki-process-inbox` to ingest it."

## Output format

```
## Answer

{Direct answer in 1-3 sentences, with inline citations}

## Supporting detail

{1-3 paragraphs with more context, also cited}

## Fidelity note

{Only if the answer depends on summary-only or excerpts-level sources}

## Sources

- [Most important source 1](relative/path.md)
- [Most important source 2](relative/path.md)
- [...up to 5 total]

## Gaps (optional)

{Only if relevant}

## Suggested follow-up (optional)

{Only if relevant}
```

Keep answers concise. A query answer that's 800 words long is almost always doing too much — if the question is big, answer the narrowest sub-question and point the user at the full sources for the rest.

## Critical rules

### DO:
- **Walk every tier `Resolve-WikiTiers` returns**, in rank order: the local `agent/` plus each `shared/<slug>/agent/wiki/` (the `wiki/` subtree only — never the inherited `work/`, `raw/`, or `_inbox/`). Do not hardcode `shared/dv`.
- **Name the governing tier when a registry position answers the question.** If `wiki/system/policies.md` (or the product tier's grandfathered `hso-overrides.md`) holds a position on the concern asked about, that position IS the answer — cite the rule ID and the tier that holds it, e.g. *"the `acme-prg` governance tier mandates this (PRG-SECURITY-001)"*. `Resolve-Policy -Concern <c>` computes the winner; a position applied without naming its tier is exactly the buried deviation [ADR 0061](../../../agent/wiki/decisions/0061-tier-precedence-specificity-plus-binding.md) D1 forbids.
- **Flag an unratified position.** A row with `Status: PROPOSED` resolves, but say so — only `VALIDATED` is authoritative.
- **Mention an applied waiver.** If the project waives an inherited `mandatory`, the answer is the project's position *and* the fact that it is a recorded deviation, with the approver and expiry.
- **Start from `index.md`.** Don't brute-force grep until you've oriented.
- **Cite every non-obvious claim** with an inline markdown link to the source file.
- **Respect the fidelity ceiling.** Claims from summary-only chains can't be verbatim.
- **Follow `supersedes:` chains** to find the current version of any superseded content.
- **Say "I don't know"** when the wiki doesn't contain the answer — suggest a follow-up skill if one fits.
- **Use topic anchors as entry points**, not as answer sources. An anchor surfaces every relevant SOP/reference/ADR/digest/skill for a subject; your answer comes from the linked files, not from the anchor body.
- **Prefer SOPs over digests** for "how do we do X?" or "what's our standard for X?" — SOPs are the authoritative HSO-authored methodology.
- **Prefer digests over raw files** for "what did the meeting say?" — digests are the structured summary.

### DO NOT:
- **Fabricate content.** If the wiki doesn't know, you don't know.
- **Quote verbatim from `summary-only` sources.** The fidelity ceiling propagates through the query path too.
- **Answer from raw files** when a digest exists. Digests are the intended read surface; raw is the source of truth the digest cites.
- **Read every candidate file.** Triage to 3-5 — more than that and context starts to degrade.
- **Ignore `status: superseded`.** If you find a superseded ADR, follow the `supersedes:` pointer forward to the current one.
- **Return a summary without citations.** Every claim needs a linkable source.
- **Walk `.gitignore`'d or out-of-scope folders.** `_inbox/`, `raw/`, and workspace-management docs at the repo root are not query targets.

## Example

**User:** "Why did we decide to use polymorphic lookups for the intake table?"

**Skill actions:**

1. Walk `agent/` and every tier `Resolve-WikiTiers` returns (in a dv-only consumer that is just `shared/dv/agent/wiki/`).
2. Read `agent/index.md` — the Decisions and Topics sections look most relevant.
3. Grep for "polymorphic" in `wiki/` and `work/`. Candidates:
   - [`agent/wiki/topics/polymorphic-lookup.md`](../../../agent/wiki/topics/polymorphic-lookup.md) — product-level topic
   - [`agent/wiki/decisions/0009-intake-table-shape.md`](../../../agent/wiki/decisions/0009-intake-table-shape.md) — project-level ADR (hypothetical)
   - [`agent/wiki/digests/2026-03-12_intake-design-review.md`](../../../agent/wiki/digests/2026-03-12_intake-design-review.md) — digest of the design meeting (hypothetical)
4. Read all three.
5. Check fidelity chain — the digest cites a Teams meeting capture with `fidelity: excerpts`, which means direct-quoted decisions are OK.
6. Synthesise:

```
## Answer

The intake table uses a polymorphic lookup because it must reference three different source
record types (Contact, Lead, Account) and the target set is small and stable — the exact
case documented in [wiki/topics/polymorphic-lookup.md](../../../agent/wiki/topics/polymorphic-lookup.md).
The decision was formalised in [ADR 0009 — Intake table shape](../../../agent/wiki/decisions/0009-intake-table-shape.md).

## Supporting detail

The alternative considered was a junction table with three FK columns, one per source type. That
was rejected because it required fan-out joins for every query and duplicated the routing logic
across queries and form scripts ([ADR 0009](../../../agent/wiki/decisions/0009-intake-table-shape.md#alternatives-considered)).

The polymorphic approach uses the standard HSO naming and cascade defaults: `CascadeDelete = RemoveLink`,
relationship schema name auto-generated, `_id` suffix on the lookup column
([wiki/topics/polymorphic-lookup.md](../../../agent/wiki/topics/polymorphic-lookup.md#rules)).

The original discussion is captured in [digest 2026-03-12](../../../agent/wiki/digests/2026-03-12_intake-design-review.md),
where the three-target requirement was first stated by the client architect.

## Sources

- [ADR 0009 — Intake table shape](../../../agent/wiki/decisions/0009-intake-table-shape.md)
- [Topic: polymorphic-lookup](../../../agent/wiki/topics/polymorphic-lookup.md)
- [Digest: 2026-03-12 Intake Design Review](../../../agent/wiki/digests/2026-03-12_intake-design-review.md)
```

## Related

- [ADR 0001 — Adopt hybrid `agent/` wiki for product knowledge](../../../agent/wiki/decisions/0001-adopt-hybrid-wiki.md)
- [ADR 0002 — Wiki refinements](../../../agent/wiki/decisions/0002-wiki-refinements.md) — two-tree walk
- [ADR 0003 — External source captures](../../../agent/wiki/decisions/0003-external-source-captures.md) — fidelity ceiling
- **[ADR 0005 — Topics are anchors, not content. SOPs live in wiki/sop/.](../../../agent/wiki/decisions/0005-topics-are-anchors.md)** — governs how this skill reads topic pages
- [`agent/schema.md`](../../../agent/schema.md) — frontmatter fields this skill reads
- `aidevme-wiki-update-topic` — suggested follow-up when the wiki has digests but no topic page
- `aidevme-wiki-write-decision` — suggested follow-up when the wiki has analysis but no ADR
- `aidevme-wiki-lint` — run before or after querying if the wiki seems inconsistent

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
