---
name: hso-wiki-ingest-transcript
layer: atomic
scope: core
description: |
  Ingest a meeting transcript into the project knowledge base. Handles local `.docx` files from Teams, SharePoint/Teams sources synced to OneDrive, HDC Local Capture session folders (local-capture tray-app output: `transcript.txt` + `session_meta.json` + `screenshots/auto|manual` — triages the screenshots and moves the valuable frames into `agent/raw/screenshots/`), and meetings with no retained recording (delegates to `hso-wiki-capture` for a summary-only capture). Writes raw transcript to `agent/raw/transcripts/` and a structured digest with participants, key topics, decisions, and action items to `agent/wiki/digests/`; adds a log entry (fragment under `agent/log/`, ADR 0062). Use for "ingest a transcript", "process a meeting transcript", "ingest this recording/session folder", "log the standup", or any Teams/Zoom/local-capture transcript conversion.
---

# Meeting Transcript Ingestion

Converts a meeting transcript into the canonical two-file pair: an immutable raw transcript (or capture, if there's no local file) plus a structured digest in `wiki/digests/` that cites it.

## Capture vs ingest — which do I use?

**Use `hso-wiki-capture` directly** when you only need a pointer + snapshot in `raw/` and don't want a full digest yet. Example: you pasted a Teams meeting link and a one-paragraph note into `_inbox/`, and you want it citable but you're not ready to extract participants, decisions, and action items.

**Use this skill (`hso-wiki-ingest-transcript`)** when you want the full pipeline — a raw transcript plus a structured digest with participants (explicitly named), key discussion topics, decisions, action items, open questions, and pain points. The digest is the intended read surface; raw is the immutable source it cites.

**The two skills compose, they don't compete.** When this skill is invoked on a non-local source (Teams meeting with no retained recording, for example), it delegates to `hso-wiki-capture` to write the raw `.md` record, then writes its own digest on top of that capture. Capture is a primitive that ingest reuses.

| I have... | I want... | Use |
|---|---|---|
| A local `.docx` Teams transcript | Full digest with participants, decisions, action items | `hso-wiki-ingest-transcript` |
| An HDC Local Capture session folder (`transcript.txt` + `screenshots/`) | Full digest plus curated screenshot frames | `hso-wiki-ingest-transcript` |
| A Teams meeting link, no recording, some notes | A citable record, not a full digest | `hso-wiki-capture` |
| A Teams meeting link, no recording, some notes, AND I want the digest | Full digest citing a summary-only capture | `hso-wiki-ingest-transcript` (delegates to capture, inherits fidelity ceiling) |
| A URL to something that isn't a meeting | A citable record | `hso-wiki-capture` (or `hso-wiki-ingest-discovery-artifact` if you also want a discovery digest) |

## Critical rule: never assume participant identity

**Never guess or infer a participant's role/title or organization.** Only populate these fields if they're **explicitly stated in the transcript itself** — e.g. someone says "I'm the CIO" or is introduced as "our consultant from HSO". Context clues, meeting invites, or assumptions about who "sounds like" a client vs. consultant are NOT sufficient.

If role or organization is not explicitly stated:

1. **Check existing digests** in `agent/wiki/digests/` — the participant may have been identified in a previous meeting.
2. **Check `agent/wiki/people/`** for an existing person page.
3. If not found, **ask the user** — they can look up roles and affiliations.
4. Only if none of the above, use `—` (em-dash) as a placeholder.

**Why this rule is load-bearing downstream.** The requirements and story skills grade every piece of evidence by *who* said it, looked up from a per-area authority register keyed on `wiki/people/` slugs ([Source Authority and Evidence Grading SOP](../../../agent/wiki/sop/requirements-engineering/source-authority-and-evidence-grading-best-practices.md), § 3 row rules and § 6 elicitation practice). A guessed identity there puts a requirement in a named person's mouth. Two consequences for the digest: (1) when a laptop microphone labels every in-room voice under one participant, say so once in the digest header and in every quote that rests on it ("in-room speaker — room mic labelled X"), never re-attribute; (2) when a participant states their role or is introduced with one, record it verbatim — that statement is the artifact the authority register cites.

## Configuration

Read from `CLAUDE.local.md`: **Author Name** (for the `people:` field and digest attribution)

## Workflow

### 0. Determine the source location

Ask: **"Where is the transcript located?"**

Three paths:

| Situation | What to do |
|---|---|
| **Local `.docx` file** (already on disk or a user-provided path) | Proceed to Step 1 |
| **HDC Local Capture session folder** (a folder — not a single file — with `session_meta.json` and `transcript.txt` in its root) | Follow [HDC Local Capture sessions](#hdc-local-capture-sessions-in-place-of-steps-1-2-and-3) in place of Steps 1–3, then continue at Step 4 |
| **SharePoint / Teams channel with a synced recording** | Provide the OneDrive sync instructions below, then proceed to Step 1 once the user gives you the local OneDrive path |
| **Meeting has no local transcript and no retained recording** | Stop and delegate to [`hso-wiki-capture`](../hso-wiki-capture/SKILL.md). The result is a `fidelity: summary-only` capture + a digest that cites it. Skip Steps 1-3 of this skill and pick up at Step 4 with the captured summary as input. |

#### SharePoint / Teams sync instructions

> **To sync the SharePoint folder to OneDrive:**
>
> 1. Open the SharePoint folder in your browser using the URL you provided
> 2. Click **Sync** in the top toolbar
> 3. OneDrive creates a synced folder at a path like:
>    `C:\Users\{username}\OneDrive - HSO\{Site Name}\{Folder Path}`
> 4. Once synced, provide the local OneDrive path to continue.
>
> Example:
> - SharePoint URL: `https://company.sharepoint.com/sites/ProjectName/Shared Documents/Recordings`
> - OneDrive path: `C:\Users\JohnDoe\OneDrive - Company\ProjectName - Shared Documents\Recordings`

After syncing, run the listing helper to enumerate `.docx` files and ask the user which to ingest.

### 1. Extract text from the `.docx`

Run the bundled extraction script:

```powershell
powershell -ExecutionPolicy Bypass `
    -File "claude-code/skills/hso-wiki-ingest-transcript/scripts/Extract-DocxText.ps1" `
    -Path "<path-to-docx>" `
    -MeetingDate "YYYY-MM-DD" `
    -MeetingTitle "Meeting Title"
```

With `-MeetingDate` and `-MeetingTitle` supplied, the script writes directly to `agent/raw/transcripts/{YYYY-MM-DD}_{slug}.txt` using the canonical slug format (lowercase, hyphens for spaces). The slug matches what `hso-wiki-capture` would produce for the same title.

If you don't have date and title yet, omit those parameters — the script writes a `.txt` next to the `.docx` that you can inspect, then re-run with the real date/title once you determine them in Step 2.

### 2. Determine meeting metadata

Check these sources in order:

1. **Teams transcript filename** — often contains a date like `Topic-YYYYMMDD_HHMMSS-Meeting Transcript.docx`. Extract date from filename; use the topic portion as title.
2. **First line of extracted text** — Teams transcripts usually start with the meeting title and date.
3. **Accompanying `.metadata.json`** if present (from download scripts) — read `videoFileName`, `videoCreatedDate`, `subfolder`.
4. **Ask the user** if none of the above work:
   - **Meeting date** (`YYYY-MM-DD`)
   - **Meeting title** (short descriptive name, e.g. "Contract Epics Review")

### 3. Confirm the raw transcript path

After the extraction script runs, the raw transcript lives at `agent/raw/transcripts/{date}_{slug}.txt`. This file is **immutable** — once written, it's never edited. If the transcript needs to be re-extracted (e.g. corrected .docx), write a new file with a `-v2` suffix rather than overwriting.

The raw transcript is intentionally saved as **plain text**, NOT markdown. Don't reformat it with speaker attribution headings or other markup — the digest is where the value is.

### HDC Local Capture sessions (in place of Steps 1, 2, and 3)

**HDC Local Capture** is a local caption-capture tray app that runs on a consultant's laptop during a Teams meeting. It scrapes live captions into a timestamped transcript and captures **screenshots of the shared content area** — automatically on visual change (`screenshots/auto/`) and on-demand via hotkey (`screenshots/manual/`). The screenshots are the differentiator: they show what was *on screen* while people talked — essential for reverse demos of legacy systems and troubleshooting sessions, where the digest can pair "what they said" with "what they showed".

**Recognize a session folder** by its root contents (folder name is typically `YYYY-MM-DD <Meeting Title>`, e.g. `2026-03-11 Contoso Kickoff`):

| File / folder | Meaning | Ingest? |
|---|---|---|
| `session_meta.json` | `{ "Subject": ..., "StartTime": ... }` — the signature file; with a transcript beside it, this is an HDC session | Metadata only |
| `transcript.txt` | Timestamped live-caption transcript, `[HH:MM:SS] Speaker: Text` per line | **Yes** — this is the raw transcript |
| `whisper_transcript.txt` | Audio-fallback transcription (only when caption scraping failed; no speaker labels) | Only if `transcript.txt` is absent/empty |
| `chat.txt` | Meeting chat with sender + timestamp (optional) | Yes, if present |
| `screenshots/auto/`, `screenshots/manual/` | `HH-mm-ss.png` captures of the shared content area | **Triage** (below) |
| `raw_session.json`, `processed.marker` | Crash-safe session buffer and processing marker — working files | **Never** |

#### LC-1. Metadata

Read `Subject` and `StartTime` from `session_meta.json` (fall back to the folder name). Date = `StartTime` date; title = `Subject`. Confirm with the user only if these conflict or look wrong.

#### LC-2. Raw transcript

Copy `transcript.txt` **verbatim** to `agent/raw/transcripts/{date}_{slug}.txt` — no extraction script, no cleanup. Live-caption scraping leaves artifacts (repeated lines, bursts sharing one timestamp, an occasional inverted `Text: Speaker` line): leave them in raw — the digest is where interpretation happens. If `chat.txt` exists, copy it to `agent/raw/transcripts/{date}_{slug}_chat.txt` and list it as an additional digest source.

#### LC-3. Screenshot triage

Not every capture is valuable — **look at every image** (Read the PNGs; never keep or drop on filename alone) and keep the frames that carry information the digest will cite:

- **`manual/` frames were deliberate** — the consultant pressed the hotkey because that screen mattered. Strong presumption of keep.
- **`auto/` frames are change-detections** — judge each one. Keep unique, information-bearing shared content: legacy-system screens, error dialogs, data grids, forms, diagrams, configuration pages. Drop near-duplicates (keep the most complete/readable of a run), mid-transition frames, video-gallery/faces-only frames, and blanks.
- **Use the timeline to judge value**: the `HH-mm-ss` filename aligns with the `[HH:MM:SS]` transcript timestamps — a frame captured while a participant is describing a pain point or walking a workflow is exactly what the digest wants to show.

Copy the keepers to `agent/raw/screenshots/{date}_{slug}/`, **keeping the original `HH-mm-ss.png` names** so frames stay joinable to the transcript. Then write a frame index at `agent/raw/screenshots/{date}_{slug}/{date}_{slug}_frames.md`: one line per kept frame (timestamp, provenance `auto`/`manual`, what it shows), plus the kept/dropped counts so the pruning is auditable. The index and frames are raw artifacts — immutable once written, like any `raw/` content.

Then continue at **Step 4**. In the digest: add the frames folder's index file to `sources:` alongside the raw transcript, and **embed key frames inline** in the topic sections they belong to (`![caption](../../raw/screenshots/{date}_{slug}/HH-mm-ss.png)`) — a screen-tour section ordered by the demo flow works well for reverse-demo sessions. Key quotes are allowed (captions are near-verbatim), but quote conservatively: live captions occasionally garble words, so skip any quote whose wording looks mangled.

### 4. Generate the digest

Save to `agent/wiki/digests/{date}_{slug}.md`.

**Before writing**, read 1-2 existing digests in `agent/wiki/digests/` (if any) to match the project's established tone and detail level.

Use this template exactly. Fill every frontmatter field — use `—` for unknowns but never omit a field.

````markdown
---
title: "Digest — {Meeting Title}"
type: digest
status: active
scope: <product | project | personal>
client: <client-id or "internal">
project: <project-id>
topics: [<topic-slugs>]
people: [<person-slugs>]
sources:
  - ../../raw/transcripts/{date}_{slug}.txt
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---

# Digest — {Meeting Title}

**Date:** {Month Day, Year}
**Duration:** ~{estimate from word count, ~150 words/min} minutes
**Purpose:** {one-line purpose}

## Participants

<!-- RULE: Only fill Role/Organization from EXPLICIT statements in the transcript. Use "—" if not stated. NEVER guess. -->

| Name | Role | Organization |
|------|------|--------------|
| **{Name}** | {Role or "—"} | {Org or "—"} |

## Key discussion topics

### 1. {Topic Title}

{Summary with key quotes and context. Link to the relevant anchor page at [`wiki/topics/<slug>.md`](../topics/<slug>.md) if one exists — the anchor surfaces the SOPs, references, and decisions related to this subject.}

### 2. {Topic Title}

{Summary}

## Decisions made

- {Decision 1}
- {Decision 2}

## Action items

| Owner | Action | Due / Status |
|-------|--------|--------------|
| {Name} | {Action} | {Due date or "TBD"} |

## Open questions

- {Unresolved question}

## System pain points / limitations raised

<!-- Omit this section if no current-state limitations were discussed. -->

- {Specific limitation of the current system, tool, or process as stated by participants — preserve system name, exact constraint, workaround if described}

## Key quotes

> "{Notable verbatim quote}" — {Speaker}

## Sources

- [Raw transcript](../../raw/transcripts/{date}_{slug}.txt)
````

### 4a. If the source is a capture (no local transcript)

When Step 0 routed you to `hso-wiki-capture`, the digest's `sources:` should point at the capture file instead of a raw `.txt`:

```yaml
sources:
  - ../../raw/transcripts/{date}_{slug}.md
```

In this case:

- Add a **Fidelity note** section near the top: "The source capture is `fidelity: summary-only`. No verbatim quotes are claimed; no precise wording from the meeting is asserted."
- Do not include a **Key quotes** section — verbatim quotes from a summary-only capture violate the fidelity ceiling and will be flagged by `hso-wiki-lint` (invariant #10).

### 5. Maintain people pages and topic anchors (MANDATORY)

Ingestion leaves the wiki maintained — no dangling references handed off to a manual pass ([ADR 0065](../../../agent/wiki/decisions/0065-ingest-skills-maintain-people-and-topics.md)).

**People pages** — for each explicitly identified participant in the digest's `people:` frontmatter:

- **Page exists** → link to it from the digest, and append this digest to the page's backlink section (`## Digests this person appears in`; create that section if the page lacks one). Bump the page's `updated:`.
- **Page missing** → **create it** per the [People-pages contract](../../../agent/schema.md#people-pages--contract): `firstname-lastname` slug, `type: person`, self-anchor `people:` entry, identity block (Role / Organization / Email — `—` where the transcript doesn't state it; **never guess**), an involvement section, and a backlink section citing this digest. The never-assume-identity rule still applies — no page for an unconfirmed identity; ask the user instead.

**Topic anchors** — for each slug in the digest's `topics:` frontmatter:

- **Anchor exists** at `agent/wiki/topics/<slug>.md` → link to it from the digest, and invoke `hso-wiki-update-topic` in **auto mode** to append the digest to its Digests section.
- **Anchor missing** → delegate stub creation to `hso-wiki-update-topic` (reactive stub creation is its job), then append the digest backlink. Do not leave the slug dangling.

### 6. Add a log entry

Write a **log fragment** — a new file `agent/log/YYYY-MM-DD-HHmm-<slug>.md` containing exactly the entry (ADR 0062: `agent/log.md` is generated from fragments on main — never edit it directly). In a repo with no `agent/log/` folder (scaffolded before ADR 0062), append the entry at the top of `agent/log.md` instead. Entry format:

```
## [{date}] ingest | digest | {Meeting Title}
{source_kind: teams local-docx | teams sharepoint-sync | teams capture-only | hdc local-capture}. [{relative path to the digest}](<relative path to the digest>)
```

### 6a. Contribute to Solution Scope (consulting meetings only)

If the repo is a consulting workspace with an engagement `PROJECT_CONTEXT.md`, add any Microsoft product/module named in the meeting (the Dynamics 365 apps, Finance & Operations, Power Pages, Fabric, etc.) to that file's **Solution Scope** table as a `candidate` row, per the [Solution Scope Contribution Protocol](../../../agent/wiki/sop/presales/solution-scope-contribution.md). Match by product name (one row each), never downgrade a product that already carries a higher status, and skip this entirely in a delivery repo (no `PROJECT_CONTEXT.md`).

### 7. Run `hso-wiki-lint` (recommended)

After writing the raw file, the digest, and the log entry, run:

```powershell
powershell -ExecutionPolicy Bypass `
    -File "claude-code/skills/hso-wiki-lint/scripts/Invoke-WikiLint.ps1" `
    -AgentPath "agent"
```

Exit code 0 means the new files pass every invariant check the linter covers. Non-zero means something needs attention before the ingest is complete.

### 8. Report to the user

Tell the user:

- Where the raw transcript (or capture) was written
- Where the digest was written
- Participants identified (and any that needed user clarification)
- People pages created or updated (backlinks appended), and any participant left unconfirmed
- Topic anchors updated, and any anchor stubs created via `hso-wiki-update-topic`
- Lint result (clean / findings)

## Critical rules

### DO:

- Write raw transcripts to `agent/raw/transcripts/` as plain `.txt`, never as markdown.
- Write digests to `agent/wiki/digests/` with full frontmatter per the schema.
- Cite the raw file in the digest's `sources:` frontmatter. Use relative paths (`../../raw/transcripts/...`).
- Use `—` for unknown participant roles/orgs. Never guess.
- For HDC Local Capture sessions: triage screenshots by **looking at every image**, keep originals' `HH-mm-ss.png` names under `agent/raw/screenshots/{date}_{slug}/`, and write the frame index so the pruning is auditable.
- Delegate to `hso-wiki-capture` when there's no local file — don't invent a workflow for "summary-only" transcripts in this skill.
- Add a log fragment under `agent/log/` on every ingest (append to `agent/log.md` only in pre-ADR-0062 repos).
- **Maintain people pages and topic anchors on every ingest (Step 5, ADR 0065).** Create missing people pages for identified participants per the contract; append digest backlinks to existing ones; delegate missing topic anchors to `hso-wiki-update-topic`. Leaving dangling references for a manual pass is the failure mode ADR 0065 exists to fix.
- Run `hso-wiki-lint` after writing to catch drift immediately.

### DO NOT:

- Edit a raw transcript file after it's been written. Raw is immutable per ADR 0003. Re-extract with a `-v2` suffix if needed.
- Reformat the raw `.txt` as markdown with speaker headings. The plain format is intentional — the digest carries the structure. This includes HDC caption artifacts — copy `transcript.txt` verbatim, don't "clean it up".
- Copy an HDC session's working files (`raw_session.json`, `processed.marker`) into the repo, or bulk-copy every screenshot without triage — `raw/screenshots/` holds only the frames the digest can cite.
- Include verbatim **Key quotes** when the digest cites a `summary-only` capture. The fidelity ceiling forbids it.
- Create a topic anchor **directly** — delegate stub creation to `hso-wiki-update-topic` (Step 5) so the stub template lives in one place.
- Create a people page for an **unconfirmed** identity, or fill its identity block with guesses. The page's facts come from the transcript or the user, nothing else (ADR 0065 keeps the contract from [ADR 0012](../../../agent/wiki/decisions/0012-people-page-convention.md) §1 in force).
- Maintain a separate README.md index for digests. The wiki `index.md` (regenerated by `hso-wiki-lint`) is the catalog.
- Hardcode client names, environment URLs, or tenant info in either the raw transcript or the digest.

## Related

- [ADR 0001 — Adopt hybrid `agent/` wiki for product knowledge](../../../agent/wiki/decisions/0001-adopt-hybrid-wiki.md)
- [ADR 0003 — External source captures](../../../agent/wiki/decisions/0003-external-source-captures.md)
- [ADR 0005 — Topics are anchors, not content. SOPs live in `wiki/sop/`.](../../../agent/wiki/decisions/0005-topics-are-anchors.md) — governs how digests link to anchor pages
- [`agent/schema.md`](../../../agent/schema.md) — frontmatter schema and invariants
- `hso-wiki-capture` — sister skill for capturing non-local sources
- `hso-wiki-lint` — runs after every ingest to verify schema compliance
- `hso-wiki-update-topic` — invoked from Step 5 on every ingest: auto-mode backlink appends for existing anchors, stub creation for missing ones (ADR 0065)
- `hso-wiki-ingest-discovery-artifact` — sister skill for non-transcript documents
- [Source Authority and Evidence Grading SOP](../../../agent/wiki/sop/requirements-engineering/source-authority-and-evidence-grading-best-practices.md) — why participant identity and stated roles must be exact: downstream evidence grading keys on people-page slugs.

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
