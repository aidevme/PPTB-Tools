---
name: aidevme-wiki-update-topic
layer: atomic
scope: core
description: |
  Maintain anchor pages in `agent/wiki/topics/` — short orientation + link-dominated sections that surface digests, SOPs, ADRs, and skills under a subject area. Two modes: **auto** (mechanical append after an ingest skill writes a digest) and **synthesis** (proposes new links across SOPs / Reference / Decisions / Digests / Skills / External sections, asks per-link approval). Use for "update topic X", "create an anchor for X", or when `aidevme-wiki-lint` flags a dangling topic reference. Never authors content into a topic — only adds or proposes links; respects the fidelity ceiling.
---

# HSO Wiki Update Topic

Keeps anchor pages in `agent/wiki/topics/` alive as new material lands. Per [ADR 0005](../../../agent/wiki/decisions/0005-topics-are-anchors.md), topics are **anchors for context engineering**, not content containers. This skill maintains the link sections; it never authors methodology into a topic. The content lives in `wiki/sop/`, `wiki/reference/`, `wiki/digests/`, `wiki/decisions/`, and in HSO skills — the anchor points at all of it from one place.

## Two modes

| Mode | Trigger | What it does |
|---|---|---|
| **auto** | Called by an ingest skill after writing a digest | Stub the anchor page if missing; add the new digest to the auto-managed "Digests" section; bump `updated:`. Never touches any other section. Silent unless something goes wrong. |
| **synthesis** | Called explicitly by the user with a topic slug | Reads the anchor + scans `wiki/sop/`, `wiki/reference/`, `wiki/decisions/`, `wiki/digests/`, and HSO skill SKILL.md files for material that cites the slug or is semantically related. Proposes **new links** to add under each anchor section. Asks the user to accept, edit, or reject each proposed link. **Never proposes body content.** |

Auto mode is the default when the skill is invoked with both a topic slug and a digest path. Synthesis mode kicks in when the skill is invoked with just a topic slug.

## Running the skill

Synthesis mode is executable via [`scripts/Invoke-WikiUpdateTopic.ps1`](scripts/Invoke-WikiUpdateTopic.ps1). Do NOT reimplement the flow by hand — call the script.

```powershell
# Dry-run (default): runs Pass 1 + Pass 2, prints the proposal, no writes.
pwsh -File claude-code/skills/aidevme-wiki-update-topic/scripts/Invoke-WikiUpdateTopic.ps1 `
    -TopicSlug plugin-development -AgentPath agent

# Apply everything the dry-run showed.
pwsh -File claude-code/skills/aidevme-wiki-update-topic/scripts/Invoke-WikiUpdateTopic.ps1 `
    -TopicSlug plugin-development -AgentPath agent -Apply

# Apply everything EXCEPT specific proposals (inverse cherry-pick).
# Each -Reject entry is a substring match against the proposal's file path.
pwsh -File claude-code/skills/aidevme-wiki-update-topic/scripts/Invoke-WikiUpdateTopic.ps1 `
    -TopicSlug plugin-development -AgentPath agent -Apply `
    -Reject "wip-plugin-draft.md","old-plugin-notes.md"
```

**Parameters:**

- `-TopicSlug <string>` (required) — the anchor slug to update
- `-AgentPath <string>` (default `agent`) — path to the local wiki root
- `-Apply` (switch) — default is dry-run; `-Apply` writes the edits
- `-Reject <string[]>` — comma-separated substring matches; any proposal whose file path matches any reject string is skipped on apply. Use this for cherry-picking rejects, since listing accepts would be tedious for the common case. Both `-Reject "a.md","b.md"` and `-Reject "a.md,b.md"` work: under `pwsh -File` every argument reaches the script as a literal string, so the script splits embedded commas itself.

**Reading the apply summary.** `Applied` counts links actually written. `Already linked` counts proposals whose target the anchor already pointed at — the normal steady state, not a problem: Pass 1 re-proposes every tagged file on every run, so a mature anchor reports mostly `Already linked`. `Skipped (rejected)` counts `-Reject` matches. A re-run over an unchanged wiki writes nothing and is a byte-identical no-op.

**What the script does:**

1. Loads keyword sets from `scripts/../references/anchor-keywords.md` (shared product-tier sidecar) and overlays `<AgentPath>/wiki/topics/anchor-keywords.md` (project-local sidecar, optional). Project-local wins on slug collisions so consuming repos can override without forking the shared file.
2. If the anchor page doesn't exist, stubs it from the template (only when `-Apply` is set; dry-run reports that it would stub it).
3. **Pass 1 (frontmatter match)** — walks `wiki/sop/`, `wiki/reference/`, `wiki/decisions/`, `wiki/digests/` recursively for files whose `topics:` frontmatter includes the slug. Each hit becomes a one-edit proposal (link into the appropriate anchor section).
4. **Pass 2 (keyword fallback)** — walks the same folders filtering to files with missing or empty `topics:`, case-insensitive substring-matches the body against the slug's keyword set. Each hit becomes a two-edit proposal (link into anchor + slug appended to the file's `topics:` frontmatter). Pass 2 only runs on untagged files, per the DO/DO-NOT rules below.
5. Prints the proposal grouped by section with Pass 1 and Pass 2 clearly labelled.
6. On `-Apply`: writes the edits, deduplicates against existing links in the anchor, bumps the anchor's `updated:` frontmatter to today.

**Link shape.** Generated links are relative to the anchor's own directory — `../decisions/<file>.md` from `wiki/topics/`. The label is the target's frontmatter `title:`, falling back to its first H1, then to the filename stem, so a generated entry reads like the curated ones beside it. Deduplication compares the **resolved target file**, not the link text: a file already linked by hand — in any relative spelling, under any label, with or without an anchor fragment — is recognised as linked and left exactly as the human wrote it.

**Scope note — the multi-tree walk now ships** ([ADR 0006](../../../agent/wiki/decisions/0006-tier-inheritance-via-shared-junction.md) D1/D2, [ADR 0007](../../../agent/wiki/decisions/0007-visible-scaffolding-and-multi-product-inheritance.md), implemented under [ADR 0061](../../../agent/wiki/decisions/0061-tier-precedence-specificity-plus-binding.md) D7). The script walks the local tree **and every inherited tier**, in rank order, via `Resolve-WikiTiers` from [`aidevme-shared-scripts`](../../aidevme-shared-scripts/SKILL.md):

- Each tier's `wiki/{sop,reference,decisions,digests}` is searched — `wiki/` **only**, never an inherited `work/`, `raw/`, or `_inbox/` (schema invariant #18 / [ADR 0038](../../../agent/wiki/decisions/0038-published-surface-boundary-and-release-governance.md)).
- Inherited hits are labelled with their tier in the proposal, e.g. `[governance: acme-prg]` or `[product: dv]`, so a reviewer can see that accepting one adds a through-the-junction link to someone else's tier rather than a local file.
- **Pass 2 degrades to link-only for inherited files** — see below.
- Keyword sidecars merge across tiers, least specific first, so the most specific tier wins a slug collision.

The banner prints the tiers walked (`Tiers walked: project:local < governance:acme-prg < product:dv`). If the shared helper cannot be resolved, the script walks the local tree only and **says so** rather than silently under-reporting.

Auto mode (the ingest-skill callback path) is documented below but not yet implemented in the script.

## Configuration

Read from `CLAUDE.local.md`: **Author Name** (for attribution in the log entry, if the user requests it)

## Workflow

### 1. Verify the target repo has the wiki layout

Check `agent/wiki/topics/` exists. If not, point the user at `hso-dataverse-init-repo` or `aidevme-wiki-scaffold-project` and stop.

### 2. Parse inputs

Two input patterns:

- **Auto mode:** `topic_slug` + `digest_path` (both provided by the calling ingest skill)
- **Synthesis mode:** `topic_slug` only (provided by the user)

If only a digest path is provided, extract all topic slugs from the digest's `topics:` frontmatter and run auto mode once per topic.

### 3. Check whether the anchor page exists

Target path: `agent/wiki/topics/<topic_slug>.md`

If the file exists, jump to the relevant mode. If it doesn't:

- **Auto mode:** create a stub (see template below) with the first digest already in the Digests section.
- **Synthesis mode:** create a stub, then proceed with link scanning.

### 4a. Auto mode — append backlink to Digests section

Open the anchor page. Find the auto-managed Digests section:

```markdown
## Digests

<!-- This section is auto-managed by aidevme-wiki-update-topic. Do not edit manually. -->
```

If the section doesn't exist, add it in the correct location (between Decisions and Skills, per the stub template order).

Append a new bullet:

```markdown
- [{digest_date} — {digest_title}](../digests/{digest_filename}.md)
```

**Sorting:** keep the list sorted newest-first by the digest's `created:` date (from frontmatter), not by the order of appends.

**Deduplication:** if the exact same digest path already exists, do not append a second entry — just bump the anchor's `updated:` frontmatter and move on.

Bump the anchor's `updated:` field in the frontmatter to today's date. Do not touch any other field or section.

**Do not touch any section other than Digests in auto mode.** This includes the orientation paragraph, SOPs, Reference, Decisions, Skills, External, and Related topics.

### 4b. Synthesis mode — propose new links across sections

Synthesis runs in **two passes**. Pass 1 is the authoritative frontmatter match; Pass 2 is a keyword fallback that bootstraps fresh migrations where nothing is tagged yet.

#### Pass 1 — frontmatter match (authoritative)

Read the anchor page and scan these locations for material whose `topics:` frontmatter cites this slug:

- **`wiki/sop/**/*.md`** — any SOP whose `topics:` includes this slug → propose adding under **SOPs** section
- **`wiki/reference/*.md`** — any reference whose `topics:` includes this slug → propose adding under **Reference** section
- **`wiki/decisions/*.md`** — any ADR whose `topics:` includes this slug → propose adding under **Decisions** section
- **`wiki/digests/*.md`** — any digest whose `topics:` includes this slug → propose adding under **Digests** section
- **`claude-code/skills/*/SKILL.md`** — any skill that describes behavior related to this subject → propose adding under **Skills** section (this requires the user's judgment; the skill proposes candidates and the user confirms)

#### Pass 2 — keyword fallback (bootstrap for fresh migrations)

**Why this exists.** On a fresh migration (e.g. a newly-scaffolded consuming repo that just ran `aidevme-wiki-scaffold-project` and imported a legacy SOP folder), nothing has `topics:` frontmatter yet. Pass 1 returns zero hits, synthesis produces an empty proposal, and migrated content stays orphaned under empty anchor pages. The fallback closes that gap.

**How it runs.** Load the per-anchor keyword set from [`references/anchor-keywords.md`](references/anchor-keywords.md). For the current anchor slug, walk the same four folders as Pass 1 (`wiki/sop/`, `wiki/reference/`, `wiki/decisions/`, `wiki/digests/`) plus `claude-code/skills/*/SKILL.md`. For each file whose `topics:` frontmatter is **missing or empty**, case-insensitive grep the body against each keyword phrase in the anchor's set. A substring match on any phrase is a hit.

**What a hit proposes.** Each fallback hit proposes **two edits** reviewed together in one approval step:

  a) **Add the file as a link** under the anchor's matching section (SOPs / Reference / Decisions / Digests / Skills), exactly as Pass 1 would.
  b) **Add the anchor slug to the file's `topics:` frontmatter.** Create the `topics:` field if it's missing; append to it if it exists but doesn't already contain the slug.

Edit (b) is what makes the fallback self-healing: after the user accepts, the file is now tagged, and the next synthesis run picks it up in Pass 1 — Pass 2 is a one-shot cost per file.

**Inherited files get edit (a) only.** When a Pass 2 hit lands in an inherited tier, the link is proposed as normal and the frontmatter half is **skipped**, because every `shared/<slug>/agent/` tree is read-only from a consuming repo (schema invariant #15 / [ADR 0006 D2](../../../agent/wiki/decisions/0006-tier-inheritance-via-shared-junction.md)). The proposal says so inline: `(link-only: inherited file, frontmatter edit skipped)`.

Pass 2's self-healing property is therefore **lost for inherited files** — the same hit will be re-proposed on the next run until someone tags the file in the tier's own repo, where a write is legitimate. That is the cost of the read-only invariant and the correct trade: writing frontmatter through a junction would land the edit in the wrong git repo, or silently mutate the junction target, and either outcome is worse than a repeated proposal.

**Strict scope of Pass 2.** Pass 2 only runs on files whose `topics:` is missing or empty. Files with non-empty `topics:` that happen not to contain this anchor's slug are **skipped** — they're already in the tagged world, and mis-tagging is a separate problem outside this skill's responsibility. Pass 2 also never proposes body content; it only proposes a link addition and a frontmatter slug addition.

Present the combined proposals (Pass 1 + Pass 2) as a diff-style summary:

```
Proposed new links for wiki/topics/plugin-development.md:

  [Pass 1 — frontmatter match]

  [SOPs] (+2 new)
    + [../sop/plugin-development/layered-architecture-principles.md] (frontmatter topic: plugin-development)
    + [../sop/plugin-development/testing-best-practices.md] (frontmatter topic: plugin-development)

  [Digests] (+1 new)
    + [../digests/2026-04-10_cutover-planning.md] (frontmatter topic: plugin-development)

  [Skills] (+1 candidate — needs user confirmation)
    + [hso-plugin-code-review] (SKILL.md description references plugin development)

  [Pass 2 — keyword fallback, untagged files only]

  [SOPs] (+1 new, two-edit)
    + [../sop/legacy-imports/plugin-refactor.md]
        keyword hit: "IPlugin", "pluginbase"
        (a) add link under SOPs
        (b) add `plugin-development` to its `topics:` frontmatter

Accept all / edit / reject all / cherry-pick?
```

Only apply changes the user accepts. For Pass 2 hits on **local** files the two edits (link + frontmatter) are accepted or rejected as a pair — they are not separable. For Pass 2 hits on **inherited** files there is only one edit to accept (the link). Bump `updated:` once after all accepted changes are applied. **Never write body content.** The only permitted modifications in synthesis mode are: add/remove links in the anchor's sections, add the anchor slug to an untagged file's `topics:` frontmatter (Pass 2 only), and update the anchor's `updated:` timestamp.

### 5. Frontmatter maintenance

Whenever the skill modifies an anchor page (in either mode), it MUST:

- Bump `updated:` to today's date
- Preserve `created:` exactly as-is
- Not change `title`, `type`, `scope`, `client`, or `project` without explicit user permission
- Preserve the full list under `topics:` (the anchor may self-reference for indexing purposes)

### 6. Add a log entry

Write the entry as a **log fragment** — a new file `agent/log/YYYY-MM-DD-HHmm-<slug>.md` (ADR 0062: `agent/log.md` is generated from fragments on main — never edit it directly; in a repo with no `agent/log/` folder, append at the top of `agent/log.md` instead). In auto mode, a brief entry:

```
## [{YYYY-MM-DD}] lint | topic | {topic_slug} — +1 digest backlink
Auto-appended {digest_filename} to the Digests section.
```

In synthesis mode, append:

```
## [{YYYY-MM-DD}] lint | topic | {topic_slug} — +N links across sections
Human-accepted additions: {counts per section}. See [../wiki/topics/{slug}.md](../wiki/topics/{slug}.md)
```

### 7. Run `aidevme-wiki-lint` (synthesis mode only)

After a synthesis-mode update, run the linter to verify the anchor's frontmatter is still valid, all new links resolve, and invariant #14 (topics are anchors, not content) is not violated. In auto mode, skip — the calling ingest skill will run lint once at the end of its batch.

## Stub template for new anchor pages

When creating an anchor from scratch (either mode), use this template. The orientation paragraph is a one-sentence placeholder for the user to fill in later. Every link section starts empty; sections are populated by subsequent auto/synthesis runs.

````markdown
---
title: "<Subject name (human-readable)>"
type: topic
status: draft
scope: <product | project | personal>
client: <client-id or "internal">
project: <project-id>
topics: [<topic_slug>]
people: []
sources: []
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---

# <Subject name>

_TODO: one short paragraph orienting the reader to this subject — what it means, when it matters, what distinguishes it from related subjects. Keep it to 2–4 sentences. This is the only prose on this page._

## SOPs

_(HSO-authored methodology — populated by synthesis mode from `wiki/sop/` entries whose frontmatter topics include this slug)_

## Reference

_(External authoritative material — Microsoft Learn, vendor docs, XSD schemas — populated from `wiki/reference/`)_

## Decisions

_(ADRs relevant to this subject — populated from `wiki/decisions/` entries whose topics include this slug)_

## Digests

<!-- This section is auto-managed by aidevme-wiki-update-topic. Do not edit manually. -->

## Skills

_(HSO skills that act on this subject — populated by synthesis mode with user confirmation)_

## External

_(Microsoft Learn URLs, vendor documentation, community resources — added by the user)_

## Related topics

_(Other anchor pages in `wiki/topics/` that are conceptually adjacent)_
````

Fill `<topic_slug>` in frontmatter `topics:` with the slug itself — this makes the anchor self-indexing.

## Critical rules

### DO:
- **Topics are anchors, not content.** Every modification you make is a link addition/removal, a timestamp bump, or the initial orientation-paragraph stub. Nothing else.
- **Separate machine-managed from human-managed sections.** "Digests" is machine; every other section is human (populated by synthesis mode with user approval, or by hand).
- **Bump `updated:` on every modification.**
- **Preserve the orientation paragraph.** If it's been filled in by a human, never touch it.
- **Dedupe links across all sections.** Same target, same section = one entry.
- **Keep "Digests" sorted newest-first.**
- **Create anchor stubs when an ingest skill references a missing topic.** Reactive creation is this skill's reason for existing.
- **Run Pass 2 (keyword fallback) only on files whose `topics:` is missing or empty.** Pass 2 is for bootstrapping fresh migrations — once a file is tagged, Pass 1 owns it.
- **Treat Pass 2 hits as two-edit pairs.** The link addition and the frontmatter slug addition are accepted or rejected together; never apply one without the other.

- **Never write under `shared/<slug>/`.** Every inherited tier is read-only from a consuming repo (schema invariant #15). The script enforces this by construction — Pass 2's frontmatter half is skipped for inherited files — but the rule binds you too when you hand-apply a proposal.

### DO NOT:
- **Write body content.** No summaries, no "key insights", no "when to apply" prose, no bulleted opinions. The content lives in the files the anchor links to. If you find yourself writing a paragraph that explains a concept, stop — that belongs in a SOP, not an anchor.
- **Touch sections other than Digests in auto mode.**
- **Apply synthesis changes without explicit user confirmation.** Even adding a single link needs accept/reject.
- **Promote content from a digest into the anchor.** The anchor links to the digest; the digest contains the synthesis. Do not flatten.
- **Create anchor pages for slugs that aren't referenced anywhere.** This skill is reactive — it responds to `topics:` frontmatter references in new files, not speculative anchor creation.
- **Run Pass 2 against files that already have a non-empty `topics:` field.** If a file is tagged but missing this anchor's slug, that's a tagging decision the file's author made — leave it alone. Pass 2 is strictly for untagged files.
- **Write body content via Pass 2.** The fallback only proposes a link in the anchor + a slug in the matched file's frontmatter. It never edits the matched file's body, and it never edits the anchor's orientation paragraph.
- **Modify the frontmatter `topics:` list to remove self-references.** Self-reference is load-bearing for the index.
- **Touch the "Digests" section from any other skill.** This skill owns it.
- **Violate invariant #14.** Topics whose non-link body exceeds a short orientation paragraph are drift — `aidevme-wiki-lint` will flag them.

## Example (auto mode)

**Input from calling ingest skill:**
- `topic_slug: cutover`
- `digest_path: ../wiki/digests/2026-04-10_cutover-planning.md`

**Actions:**
1. Check [`agent/wiki/topics/cutover.md`](../../../agent/wiki/topics/cutover.md) — doesn't exist.
2. Create stub using the template; slug = `cutover`, scope derived from current repo.
3. Add the digest to the Digests section: `- [2026-04-10 — Digest — Cutover Planning](../digests/2026-04-10_cutover-planning.md)`
4. Set `updated:` to 2026-04-10.
5. Append log entry: `## [2026-04-10] lint | topic | cutover — +1 digest backlink`
6. Return control to the calling skill. No lint run; the caller handles that.

## Example (synthesis mode)

**User:** "Refresh the plugin-development anchor with any new SOPs and ADRs"

**Actions:**
1. Find [`agent/wiki/topics/plugin-development.md`](../../../agent/wiki/topics/plugin-development.md); read it.
2. **Pass 1 (frontmatter):** scan `wiki/sop/`, `wiki/reference/`, `wiki/decisions/`, `wiki/digests/` for files whose `topics:` includes `plugin-development` — say 5 new SOPs and 1 new digest. Scan `claude-code/skills/*/SKILL.md` by name/description — 2 skill candidates.
3. **Pass 2 (keyword fallback):** load the `plugin-development` keyword set from [`references/anchor-keywords.md`](references/anchor-keywords.md). Walk the same folders, filtering to files whose `topics:` is missing or empty. Two untagged SOPs in a freshly-imported legacy folder hit on `"iplugin"` and `"pluginbase"`.
4. Present the combined diff: Pass 1 additions, then Pass 2 two-edit pairs — wait for user confirmation.
5. User accepts the Pass 1 SOPs, digest, and one Pass 2 pair; rejects the second Pass 2 hit and the skill candidates (already linked).
6. Apply accepted edits. For each accepted Pass 2 pair: add the link to the anchor, **and** append `plugin-development` to the matched file's `topics:` frontmatter. Bump the anchor's `updated:`.
7. Append log entry.
8. Run `aidevme-wiki-lint` to verify invariant #14 and that all new links resolve.

## Related

- [ADR 0001 — Adopt hybrid `agent/` wiki for product knowledge](../../../agent/wiki/decisions/0001-adopt-hybrid-wiki.md)
- [ADR 0003 — External source captures](../../../agent/wiki/decisions/0003-external-source-captures.md) — explains the fidelity ceiling
- **[ADR 0005 — Topics are anchors, not content. SOPs live in wiki/sop/.](../../../agent/wiki/decisions/0005-topics-are-anchors.md)** — load-bearing for this skill's behavior
- [`agent/schema.md`](../../../agent/schema.md) — anchor rule and invariant #14
- `hso-wiki-ingest-transcript`, `hso-wiki-ingest-discovery-artifact` — call this skill in auto mode after writing a digest
- `aidevme-wiki-lint` — runs after synthesis-mode updates; enforces invariant #14

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
