---
title: Wiki Schema & Conventions
type: system-state
status: active
scope: project
created: 2026-09-10
updated: 2026-09-10
---

# Schema & Conventions

Authoritative rules for how `agent/` is organised. AI agents MUST follow this. Humans may edit by
hand but should respect the invariants. This is the project-tier wiki; the product tier is inherited
via `shared/dv/agent/wiki/`.

## Primary value: context engineering via anchors

The wiki exists to give AI agents and humans **one anchor page per subject**. When a task touches a
subject, the anchor is the single page to load that surfaces everything relevant: the authoritative
SOP, external references, related decisions, past digests, and consuming skills. Anchors are
continuously maintained so the wiki's value compounds over time.

Anchors are not content. Anchors are navigation. The content lives in `wiki/sop/` (authored),
`wiki/reference/` (external), `raw/` + `wiki/digests/` (ingested and summarised), `wiki/decisions/`
(ADRs), and in skills. Anchors point at all of it from one place.

## Three tiers

| Tier | Location | Scope |
|---|---|---|
| **Product** | inherited via `shared/dv/agent/wiki/` | Reusable methodology + platform knowledge, versioned centrally |
| **Project** *(this repo)* | `agent/wiki/` | One client, one engagement |
| **Personal** | a separate per-human repo | One human's private working memory |

Consuming repos inherit the product wiki via the `shared/` junction and overlay their own
project-tier wiki at `agent/wiki/`. `aidevme-wiki-lint` walks both trees and renders a merged `index.md`.
Personal wikis are never folded into project or product repos; promotion is a deliberate copy-up,
then delete from the lower tier.

> **Inheritance guard.** The `shared/` junction is gitignored and provisioned per machine. If it is
> absent, every "read `shared/dv/agent/wiki/...`" step reads nothing. Run
> `agent-src/sync/check-shared.ps1 -Strict` at first run / in CI to fail fast with a clear message.

## Four-layer model

1. **`raw/`** — immutable sources. The agent **reads** here but **never writes or modifies** these
   files. Ingest skills write once at capture time and treat the files as frozen. `raw/` holds actual
   local files AND **capture files** (markdown pointers + snapshot content) for external sources.
2. **`_inbox/`** — transient drop zone. Anything can land here. `aidevme-wiki-process-inbox` classifies
   each file and moves it to `raw/` (if a source) or creates a `wiki/`/`work/` stub (if structured).
3. **`wiki/`** — compiled knowledge. Cross-cutting, durable, outlives any single project phase.
4. **`work/`** — project deliverables organised by phase.

## Captures — `raw/` entries for external sources

Teams meetings, SharePoint docs, ADO items, Slack threads — sources that cannot be synced locally are
frozen as **capture files**: markdown containing a pointer to the external source plus a snapshot of
its content at capture time. A capture is immutable and belongs in `raw/` because it plays the same
source-of-truth role as a local file. Digests cite captures exactly as they cite local files.

### Placement

By source **kind**, not locality — e.g. a Teams capture sits in `raw/transcripts/` alongside a local
`.txt` transcript. The linter distinguishes captures from local files by frontmatter `type: capture`,
not by extension.

### Capture frontmatter

```yaml
---
title: "Capture — <source title>"
type: capture
status: active
scope: product | project | personal
source_kind: teams-meeting | sharepoint-doc | ado-work-item | email | slack | url | local-file
source_location: <URL, link, or stable identifier>
source_title: <original title>
source_owner: <team, author, or tenant>
captured: YYYY-MM-DD
captured_by: <person-slug or skill-name>
fidelity: full-copy | excerpts | summary-only
access_notes: <how to re-fetch, or why it is not re-fetchable>
supersedes: <relative path to earlier capture, if re-snapshotting>
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

### Fidelity levels

| Fidelity | Meaning |
|---|---|
| `full-copy` | Verbatim content captured |
| `excerpts` | Direct quotes of load-bearing parts; not the whole thing |
| `summary-only` | Paraphrased summary; original may not be recoverable |

**Digests inherit the fidelity ceiling of their sources.** A digest citing a `summary-only` capture
must not assert anything more precise than the capture contains; the linter flags verbatim quotes of
`summary-only` sources.

### Updating an external source

Captures are immutable. To re-snapshot: (1) create a **new** capture dated at the new time, (2) set
`supersedes:` to the old capture's path, (3) leave the old capture untouched. This preserves the full
timeline of what the source said when.

### Wiki vs work — the test

> *Is this knowledge that outlives the project, or an artifact we're delivering?*

- **Wiki**: topics, stakeholder pages, ADRs, system state, source digests, reference material.
- **Work**: feature specs, TDDs, test plans, release notes, implementation notes, changelogs.
- **Bridge**: a spec in `work/specs/` may cite or spawn a topic page in `wiki/topics/`.

## Frontmatter schema

Every `wiki/*.md` and `work/*.md` file MUST start with:

```yaml
---
title: <human-readable title>
type: topic | reference | digest | spec | design | decision | person | system-state | deliverable | analysis | test
status: draft | active | superseded | archived
scope: product | project | personal
topics: [<topic-slug>, ...]               # optional; links to wiki/topics/<slug>.md
people: [<person-slug>, ...]              # optional; links to wiki/people/<slug>.md
sources: [<relative path to raw/>, ...]   # optional but REQUIRED for digests
supersedes: <relative path>               # optional; used instead of deletion
last_validated: YYYY-MM-DD                # REQUIRED for wiki/reference/ pages; flagged if >180d stale
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

Rules: `created` is set once and never changes; `updated` bumps on every material edit; `supersedes`
replaces deletion (stale pages flip to `status: superseded` and point forward); `topics`/`people`
create implicit backlinks the linter uses to maintain those pages.

## Linking

- Markdown links only: `[text](relative/path.md)`. No wikilinks, no proprietary syntax.
- Relative to the current file, so the wiki renders unchanged in Obsidian, VS Code, and ADO Wiki.
- Link to `raw/` files only from the digests that process them.
- A `work/` page may freely link to `wiki/` pages; a `wiki/` page prefers citing the specific `raw/`
  source over a `work/` deliverable.

## `log.md` format

Append-only, newest at top. Each entry:

```
## [YYYY-MM-DD] <kind> | <subject> | <title>
<optional detail / link>
```

`<kind>` ∈ { ingest, decision, milestone, spec, design, build, test, deliverable, lint }. Every
significant write to `wiki/` or `work/` appends an entry; the linter verifies coverage against git.

## `index.md` format

Categorised table of contents (not a file tree), split into a **Knowledge** section (`wiki/`) and a
**Work products** section (`work/`). Regenerated by `aidevme-wiki-lint`; human edits preserved only within
`<!-- manual -->` blocks. Every `status: active` page appears under exactly one category.

## `wiki/` folders

| Folder | Role | Shape |
|---|---|---|
| `wiki/topics/` | Anchor pages, one per subject | Short, link-dominated, no authored methodology |
| `wiki/sop/` | Authored methodology (how we do X) | Whatever length the subject needs |
| `wiki/reference/` | External authoritative material | Thin wrapper + `last_validated` |
| `wiki/decisions/` | ADRs, numbered `NNNN-title.md` | Context / Options / Decision / Consequences |
| `wiki/digests/` | Summaries of `raw/`, one per source | Cites `raw/`; inherits fidelity ceiling |
| `wiki/system/` | Current-state snapshots (schema, env map, TOPO) | Descriptive; rots as the environment changes |
| `wiki/people/` | One page per stakeholder | Biographical |

### The anchor rule

A page belongs in `wiki/topics/` iff: it orients a reader in a short paragraph; its body is dominated
by links to `wiki/sop/` / `wiki/reference/` / `wiki/decisions/` / `wiki/digests/` / skills; removing
the links leaves almost nothing; and it contains no authored methodology that could stand on its own.
If a page fails the test, route the content to `wiki/sop/` (authored), `wiki/reference/` (external),
`wiki/digests/` (summary), `wiki/decisions/` (a decision), or `wiki/people/` (a stakeholder), and
leave a thin anchor behind.

### SOP vs reference — the "who authored it" test

> *If this page rots, who changed something — us (→ `wiki/sop/`) or a vendor like Microsoft
> (→ `wiki/reference/`)?* Reference pages are thin wrappers carrying `last_validated`; the linter
> flags them when older than 180 days.

## `work/` folders

Phase folders, no numbering — navigate by name. Typical order analysis → specs → design → build →
testing → deliverables, but movement is free.

| Folder | Purpose |
|---|---|
| `work/analysis/` | Investigations, gap analyses, discovery |
| `work/specs/` | Feature specs / PRDs (requirements BEFORE implementation) |
| `work/design/` | TDDs, data models, integration contracts |
| `work/build/` | `implementation-notes/` + `changelog/` (archive under `archive/YYYY-MM.md`) |
| `work/testing/` | Test plans, results, defect logs |
| `work/deliverables/` | Client-facing final artifacts |

## Linter policy: aggressive by default

`aidevme-wiki-lint` auto-corrects wherever safe (regenerate `index.md`, merge duplicate topics,
auto-supersede stale pages, normalise frontmatter, fix moved-target links) and commits each
correction as a separate `chore(wiki-lint): ...` commit so the diff is reviewable and one
`git revert` away. `--dry-run` exists but is not the default. The linter **never** touches `raw/`.

## Invariants (what the linter enforces)

1. **Frontmatter present** on every `wiki/`/`work/` file.
2. **Digests cite sources** (at least one `sources:` → `raw/`).
3. **Links resolve** (auto-rewrite unambiguous moves).
4. **Timestamps sane** (`updated` ≥ `created`, within N days of last git touch).
5. **No orphans** (every active page reachable from `index.md`).
6. **No duplicate topic slugs** (auto-merge, supersede the older).
7. **No ADR contradictions** (flagged, not auto-resolved).
8. **`raw/` is write-once** (fail on any diff to a tracked raw/capture file).
9. **Captures have frontmatter** (`type: capture` + required fields).
10. **Fidelity ceiling respected** (no verbatim quotes of `summary-only` captures).
11. **`supersedes:` chains intact** (no broken/cyclic chains).
12. **Knowledge cites raw, not work** (`wiki/` pages must not `sources:` a `work/` folder).
13. **Reference pages validated** (`last_validated` present; >180d flagged).
14. **Topics are anchors, not content** (a topic mirroring an SOP/reference/skill body is drift).
15. **`index.md` is canonical** (regenerated each run; manual edits only in `<!-- manual -->` blocks).
16. **Visible scaffolding folders** (`agent/` and `shared/` stay un-dotted at the root; re-hiding is
    drift — `agent/` is committed, `shared/` is gitignored with OS junctions per the slug registry).
