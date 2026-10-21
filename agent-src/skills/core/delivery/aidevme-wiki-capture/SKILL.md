---
name: aidevme-wiki-capture
metadata:
  layer: atomic
  scope: core
description: |
  Freeze an external source (Teams meeting, SharePoint doc, ADO item, Slack thread, URL) as an
  immutable, timestamped capture file in agent/raw/ with correct type: capture frontmatter and a
  declared fidelity. Use when:
  (1) User says "capture this", "snapshot this meeting/page/item"
  (2) A source lives in an external system and cannot be synced as a local file
  (3) A digest needs a citable raw/ entry but the source is not a file
  Does NOT summarise into a digest (that is the ingest skills) and NEVER edits an existing capture —
  updates create a NEW dated capture with supersedes:.
---

# aidevme-wiki-capture

Not every source is a local file. This skill writes a **capture** — a markdown record of what we
knew about an external source at a moment in time — into the matching `raw/` subfolder. Authority:
[`agent/schema.md`](../../../../agent/schema.md) (Captures section).

## Placement

By source **kind**, not locality: `raw/transcripts/`, `raw/discovery/`, `raw/exports/`, etc. The
linter distinguishes captures from local files by `type: capture`, not by extension.

## Frontmatter (all required)

```yaml
---
title: "Capture — <source title>"
type: capture
status: active
scope: product | project | personal
source_kind: teams-meeting | sharepoint-doc | ado-work-item | email | slack | url | local-file
source_location: <URL / stable identifier>
source_title: <original title>
source_owner: <team / author / tenant>
captured: YYYY-MM-DD
captured_by: <person-slug or skill-name>
fidelity: full-copy | excerpts | summary-only
access_notes: <how to re-fetch, or why it cannot be re-fetched>
supersedes: <relative path to earlier capture, if re-snapshotting>
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

## Fidelity (declare honestly — digests inherit the ceiling)

| Fidelity | Meaning |
|---|---|
| `full-copy` | Verbatim content captured |
| `excerpts` | Direct quotes of load-bearing parts only |
| `summary-only` | Paraphrase; original may be unrecoverable |

A digest citing a `summary-only` capture must not quote verbatim — the linter enforces this.

## Body sections

1. Source metadata (table mirroring frontmatter). 2. Captured content (per fidelity). 3. Re-fetch
(how, or an explicit "cannot re-fetch"). 4. Used by (back-refs, maintained by the linter).

## Updating a source

Captures are immutable. To re-snapshot: write a **new** dated capture, set `supersedes:` to the old
path, leave the old file untouched. This preserves the full timeline of what the source said when.

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-10 | aidevme | Ported from prior in-house skills and neutralised for the template. |
| 2026-10-21 | aidevme | New [CHANGELOG.md](CHANGELOG.md): the skill's full history from its commits. |
