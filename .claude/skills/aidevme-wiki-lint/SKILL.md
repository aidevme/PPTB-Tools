---
name: aidevme-wiki-lint
layer: governance
scope: core
description: |
  Enforce the agent/ wiki invariants and regenerate index.md. Aggressive by default: auto-corrects
  what is safe and commits each correction as a reviewable chore(wiki-lint): commit; flags what needs
  human judgement. Never touches raw/. Use when:
  (1) User says "lint the wiki", "check the wiki", "regenerate the index"
  (2) After ingesting sources, writing digests/decisions, or moving pages
  (3) Periodic knowledge-integrity check / pre-commit
  Does NOT edit raw/ (write-once) and does NOT auto-resolve ADR contradictions.
---

# aidevme-wiki-lint

The self-committing integrity check for the `agent/` wiki. Authority for the rules is
[`agent/schema.md`](../../../../agent/schema.md); this skill executes them.

## Policy: aggressive by default

Auto-correct wherever safe (regenerate `index.md`, merge duplicate topics, auto-supersede stale
pages, normalise frontmatter, fix moved-target relative links). Commit each correction as a separate
`chore(wiki-lint): ...` commit so the diff is reviewable and one `git revert` away. A `--dry-run`
flag exists but is not the default — drift is more expensive than over-correction because everything
is in source control. **Never touch `raw/`.**

## Invariants (auto-correct where possible, else flag)

1. **Frontmatter present** on every `wiki/` and `work/` file (fill safe defaults from git where possible).
2. **Digests cite sources** — at least one `sources:` entry pointing to `raw/`.
3. **Links resolve** — no broken relative links; auto-rewrite unambiguous moved targets.
4. **Timestamps sane** — `updated` ≥ `created`, within N days of the last git touch.
5. **No orphans** — every `status: active` page reachable from `index.md`.
6. **No duplicate topic slugs** — auto-merge (keep the most recent `updated`, supersede the other).
7. **No ADR contradictions** — flagged, NOT auto-resolved (ADRs need human judgement).
8. **`raw/` is write-once** — fail on any diff to a tracked raw/capture file. Never auto-correct.
9. **Captures have frontmatter** — any `.md` in `raw/` needs `type: capture` + required fields.
10. **Fidelity ceiling respected** — a digest citing a `summary-only` capture must not quote verbatim.
11. **`supersedes:` chains intact** — no broken/cyclic supersession chains.
12. **Knowledge cites raw, not work** — `wiki/` pages must not `sources:` a `work/` folder.
13. **Reference pages validated** — every `wiki/reference/` page carries `last_validated`; >180d flagged.
14. **Topics are anchors, not content** — a topic that mirrors an SOP/reference/skill body is drift.
15. **`index.md` is canonical** — regenerated each run; manual edits preserved only in `<!-- manual -->` blocks.
16. **Visible scaffolding** — `agent/` and `shared/` stay un-dotted at the root; re-hiding is drift.

## Workflow

1. Walk `agent/` (and the inherited `shared/dv/agent/` tree, read-only) — parse frontmatter, links,
   captures.
2. Apply safe auto-corrections; stage and commit each as its own `chore(wiki-lint): <what>` commit.
3. Regenerate `index.md` (Knowledge section from `wiki/`, Work-products section from `work/`).
4. Print a report: corrected (with commit hashes) vs flagged-for-human (invariants 7, 8, 10, 13, 14).

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-10 | maciejnowicki | Ported from prior in-house skills; invariant numbering de-duplicated (was two "14"s → 14/15/16). |
