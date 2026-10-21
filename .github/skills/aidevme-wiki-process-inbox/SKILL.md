---
name: aidevme-wiki-process-inbox
metadata:
  layer: atomic
  scope: core
description: |
  Triage everything in agent/_inbox/ and route it into the wiki. For each item: if it is a SOURCE
  (transcript, discovery doc, export, screenshot), move it to the matching raw/ subfolder (or write
  a capture for a non-local source) and scaffold a wiki/digests/ stub; if it is already structured
  knowledge, create the correct wiki/ or work/ stub with frontmatter. Use when:
  (1) User says "process the inbox", "triage _inbox", "file these"
  (2) After dropping new files into agent/_inbox/
  Does NOT invent content — it classifies and scaffolds; ingestion detail is delegated to the
  ingest skills.
---

# aidevme-wiki-process-inbox

`_inbox/` is the transient drop zone. This skill empties it by classifying each item and moving it to
its permanent home. Authority for placement: [`agent/schema.md`](../../../../agent/schema.md).

## Decision per item

| Item | Route to | Then |
|---|---|---|
| Local source file (pdf/docx/xlsx/txt/img) | `raw/<kind>/` (discovery, transcripts, exports, screenshots) | scaffold a `wiki/digests/<date>_<slug>.md` stub citing it in `sources:` |
| External source (Teams/SharePoint/ADO/URL — no local file) | write a **capture** `.md` in `raw/<kind>/` with `type: capture` frontmatter (delegate to `aidevme-wiki-capture`) | scaffold a digest stub citing the capture |
| Already-structured knowledge (a topic, ADR, spec draft) | the correct `wiki/` or `work/` folder | add frontmatter; flag for the author to complete |
| Junk / duplicate | delete (or leave, flagged) | note it in the report |

## Workflow

1. List `agent/_inbox/`. For each item, classify (source vs structured; local vs external).
2. Move/write to the destination. **Never** edit a `raw/` file after writing — captures and sources
   are write-once.
3. Scaffold the paired digest/stub with correct frontmatter (`type`, `status: draft`, `sources:`,
   `created`, `updated`).
4. Append a `## [date] ingest | ...` entry to `agent/log.md`.
5. Report what moved where and what still needs a human (digest bodies, ambiguous items).

## Rules

- Classification only — do not author digest bodies here (that is the ingest skills' job).
- Ambiguous item ⇒ leave it in `_inbox/`, flagged, and ask. Do not guess a destination.

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-10 | aidevme | Ported from prior in-house skills and neutralised for the template. |
| 2026-10-21 | aidevme | New [CHANGELOG.md](CHANGELOG.md): the skill's full history from its commits. |
