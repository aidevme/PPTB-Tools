---
name: hso-wiki-ingest-screenshots
layer: atomic
scope: core
description: Triage and ingest desktop screenshots from a local folder into the agent/ wiki, sorted by customer. Reads each new shot with vision (browser URL + on-screen content) and matches its capture time to a Krisp meeting to decide the customer, then files the current project's shots as a raw image + lean digest and routes or flags the rest. Use for "process my screenshots", "triage screenshots", or "ingest screenshots". Incremental via a processed-manifest; never commits the images (possible secrets).
---

# Screenshot Triage & Ingestion

People take screenshots all day into one folder, across every client they work. This skill pulls the **new** ones, works out **which customer each belongs to** (from what's on screen plus which meeting was happening at the time), and files the ones that belong to the **current project** as a raw image + a lean digest. Everything it can't confidently place is **flagged**, not guessed.

It is the screenshot sibling of [`hso-wiki-ingest-discovery-artifact`](../hso-wiki-ingest-discovery-artifact/SKILL.md) and [`hso-wiki-ingest-transcript`](../hso-wiki-ingest-transcript/SKILL.md) — same two-file pattern (immutable raw file in `agent/raw/screenshots/` + digest in `agent/wiki/digests/`), with one extra capability: **Krisp meeting-time correlation** for classification.

## When to use this skill

- "Process / triage / ingest my screenshots"
- "Pull in the screenshots from this week's meetings"
- "File the screenshots for `<project>`"

## When NOT to use

- A single image you already know belongs to the project and want digested → use `hso-wiki-ingest-discovery-artifact` directly (no triage needed).
- A meeting transcript → `hso-wiki-ingest-transcript`.
- Bookmarking a URL / external doc → `hso-wiki-capture`.

## Configuration

Read from `CLAUDE.md` (the **project fingerprint** — what "this project" looks like):
- **Environment URL(s)** and any UAT/other org hosts · **Default Solution** / project names · **Client identifier**

Read from `CLAUDE.local.md`:
- **Author Name** (digest attribution)
- **Screenshots source folder** (under a `## Screenshots` section — see below). If absent, ask the user for the folder and offer to add the row.
- **Customer map** (the same table `hso-timesheet-builder` reads) — used for per-customer **classify hints** (title keywords + attendee email domains).
- **Customer repo paths** (optional, under `## Screenshots`) — where to route another customer's shots. No path registered → that customer's shots are reported and left in place.

> The skill is **customer-agnostic**: it never hardcodes a customer name, env URL, or folder path. Everything comes from `CLAUDE.md` / `CLAUDE.local.md` so the same skill works in any repo.

## How classification works — two signals

For each new screenshot the skill gathers two independent signals and combines them:

1. **On-screen (vision).** Read the image and extract:
   - the **browser URL bar** host, if visible — does it match a project/customer env, ADO org, or Jira org?
   - **on-screen content** — app name, entity/record titles, a customer name or logo, distinctive project terms.
2. **Meeting context (Krisp).** Resolve the shot's **capture time** (filename-encoded datetime first, then EXIF, then file mtime), then query the Krisp MCP for a meeting whose window contains that time. If that meeting's **title or attendee email domains** match a customer's hints, that is a strong customer signal — and the meeting to link the shot to.

**Decision:**

| Signals | Verdict |
|---|---|
| URL/content clearly matches a customer, **or** falls inside a clearly-matching meeting | **File** under that customer |
| Signals point at **different** customers, or both are weak/absent | **Flag** (leave in place, list for the user) |
| Clearly a customer **other** than the current project | Route (if repo path known) or **report + leave** |

> **Guardrail (per project memory):** Krisp is used here **only to file and tag**. It is never treated as a source of technical truth. A meeting placing a shot is filing metadata, not a claim about the system.

## Workflow

### 1. Resolve the range (call-time argument)

The user supplies how far back to look this run: `"last 7 days"`, `"since 2026-06-01"`, or `"all"`. Default to **last 7 days** if unspecified. This decides what to *look at*; the **processed-manifest** (Step 3) decides what's *already done*.

### 2. Build the project fingerprint + customer registry

- From `CLAUDE.md`: collect env URL hosts (e.g. the dev org host and any UAT host), solution/project names, ADO/Jira org slugs, and the client id. These identify the **current project**.
- From `CLAUDE.local.md`: load the **customer map** (classify hints per customer) and the optional **customer repo paths**.

### 3. Enumerate new shots

Run the bundled helper. It lists images in the range with a best-guess capture time, size, and a SHA-256 hash, and (given the manifest) skips anything already processed:

```powershell
powershell -ExecutionPolicy Bypass `
    -File ".claude/skills/hso-wiki-ingest-screenshots/scripts/List-Screenshots.ps1" `
    -Path "<source-folder-from-CLAUDE.local>" `
    -Since "YYYY-MM-DD" `
    -ManifestPath "agent/raw/screenshots/.processed-manifest.json"
```

(Use `-Days N` or `-All` instead of `-Since` as the range demands.) Output is a JSON array of `{ name, path, captureTime, captureSource, sizeKB, key }` (plus `sha256` if you pass `-ContentHash`). Drop any `key` already in the manifest.

> **OneDrive note:** the default `key` (`name|size|captureTime`) is computed from file metadata only — no bytes are read, so a cloud-backed OneDrive folder is **not** force-downloaded. Only pass `-ContentHash` on local, non-OneDrive folders.

**If the candidate set is large (> 25 shots):** summarise the count and date span and **confirm with the user before reading/writing** — digest-per-shot can produce a lot of files. Offer to narrow the range.

### 4. Look at each shot (vision)

`Read` each image file. Note the URL-bar host (if any) and the on-screen content per the two-signal model. Do **not** transcribe secrets — see Step 6.

### 5. Correlate to a meeting (Krisp)

For each shot's `captureTime`, query the Krisp MCP (server tools `list_meetings` / `search_meetings` / `list_activities`) for meetings on that date, and pick the one whose start–end window contains the capture time. Record its title and attendee domains. No meeting in the window → meeting signal is absent (rely on vision).

### 6. Classify and route

Apply the decision table. Then:

- **Current project** → copy the image to `agent/raw/screenshots/{date}_{slug}.png`; write a lean digest to `agent/wiki/digests/{date}_{slug}.md` (template below); link the meeting's digest if one already exists in `agent/wiki/digests/`.
- **Other customer, repo path registered** → copy raw + write the digest into **that repo's** `agent/raw/screenshots/` and `agent/wiki/digests/`. Never under this repo.
- **Other customer, no repo path** → leave in place; add to the report grouped by customer.
- **Flag (unsure)** → leave in place; add to the FLAG list in the report with the conflicting/weak signals noted.

**Secret hygiene (mandatory):** if a shot shows an API key, token, password, connection string, or personal data, **redact it** in the digest (`[redacted]`) and never paste the value. The image itself is never committed (it lives in the gitignored `agent/raw/screenshots/`).

#### Lean digest template

```markdown
---
title: "Screenshot — {short description} ({date})"
type: digest
status: active
scope: project
client: {client-id}
project: {project-id}
topics: [{topic-slugs}]
people: []
sources:
  - ../../raw/screenshots/{date}_{slug}.png
created: {YYYY-MM-DD}
updated: {YYYY-MM-DD}
---

# Screenshot — {short description}

**Captured:** {YYYY-MM-DD HH:MM} ({captureSource: filename|exif|mtime})
**Customer:** {customer} — confidence {high | medium}
**Surface:** {browser URL host or app name}
**Meeting:** {meeting title + time, or "—"}  {link to meeting digest if one exists}

## What it shows

{2–4 sentences: the screen, key labels, record names, what the user appears to be doing. Redact any secrets/PII as [redacted].}

## Why classified {customer}

- {signal — e.g. "URL host orgXXXXXXXX.crm.dynamics.com matches the project env" / "on-screen account 'Contoso UK'" / "inside meeting 'Contoso CRM sync' with @contoso.com attendees"}

## Sources

- [Raw screenshot](../../raw/screenshots/{date}_{slug}.png)
```

Keep it lean — it describes **one image**. Do not pad it into a discovery-style report.

### 7. Update the processed-manifest

Append one entry per handled shot to `agent/raw/screenshots/.processed-manifest.json`:
`{ key, captureTime, verdict, customer, target }`. This is the authority for "already done" — a `key` here is never re-read or re-digested on a later run. The manifest is per-machine local state (gitignored with the images).

### 8. Append to `agent/log.md`

One entry per run (newest first):

```
## [{YYYY-MM-DD}] ingest | screenshots | {N} filed, {M} flagged, {K} other-customer
range: {range}. digests: agent/wiki/digests/ (see run report).
```

### 9. Lint and report

Run the linter:

```powershell
powershell -ExecutionPolicy Bypass `
    -File ".claude/skills/hso-wiki-lint/scripts/Invoke-WikiLint.ps1" `
    -AgentPath "agent"
```

Then report to the user a table — **shot → capture time → customer → verdict → meeting → action** — followed by the FLAG list (what was uncertain and why) and the other-customer groups. State where digests were written and the lint result.

## Critical rules

### DO
- Read the project fingerprint, source folder, customer map, and repo paths from `CLAUDE.md` / `CLAUDE.local.md`. Ask if the source folder is missing.
- Stay incremental: skip any `key` already in the manifest; record every handled shot.
- File current-project shots as raw image (`agent/raw/screenshots/`) + lean digest (`agent/wiki/digests/`).
- Redact secrets/PII from digest text. The image is never committed.
- Confirm before writing if a run would produce more than ~25 digests.
- Use Krisp only to file/tag, never as a source of truth.

### DO NOT
- Hardcode any customer name, environment URL, ADO/Jira org, or folder path in this skill.
- Copy another customer's screenshots into this repo. Route them to their repo (if a path is registered) or leave them in place and report.
- Guess a customer from weak signals — flag instead.
- Commit `agent/raw/screenshots/`. Verify it is gitignored before filing (Step 6 preflight); if not, add it.
- Re-read or re-digest a shot whose hash is already in the manifest.
- Edit a raw image after filing it. Raw is immutable (ADR 0003).
- Overwrite an existing digest silently — ask first.

## Related

- [`hso-wiki-ingest-discovery-artifact`](../hso-wiki-ingest-discovery-artifact/SKILL.md) — non-transcript documents; this skill mirrors its two-file pattern
- [`hso-wiki-ingest-transcript`](../hso-wiki-ingest-transcript/SKILL.md) — meeting transcripts
- [`hso-wiki-capture`](../hso-wiki-capture/SKILL.md) — non-local source captures
- [`hso-wiki-lint`](../hso-wiki-lint/SKILL.md) — runs after every ingest
- [ADR 0003 — External source captures](../../../shared/dv/agent/wiki/decisions/0003-external-source-captures.md) — raw is immutable
- [ADR 0008 — Skill-to-topic coverage](../../../shared/dv/agent/wiki/decisions/0008-skill-to-topic-coverage-invariant.md) — anchored by the `wiki-operations` topic; the coverage gate is a no-op in consuming repos and enforces at promotion to `shared/dv/claude-code/skills/`
- [`agent/schema.md`](../../../agent/schema.md) — frontmatter schema and invariants

**Promotion note:** this skill is generic (reads all config; no client data) and is promotion-ready. When promoting to `shared/dv/claude-code/skills/` via `hso-skill-update-shared-skill`, add a `claude-code/skills/hso-wiki-ingest-screenshots` link to a `wiki-operations` topic in the shared product wiki so the ADR 0008 coverage gate passes there.

## Changelog

| Date | Author | Description |
|------|--------|-------------|
| 2026-06-18 | keithwhatling | Initial creation. Screenshot triage + ingest sibling of the wiki-ingest family. Two-signal classification (on-screen vision + Krisp meeting-time correlation), per-customer sort with optional cross-repo routing, incremental processed-manifest, digest-per-shot output, gitignored images with secret redaction. Bundled `List-Screenshots.ps1` helper. Dedupe uses a metadata key (`name\|size\|captureTime`) so cloud-only OneDrive files are never downloaded during enumeration; `-ContentHash` is opt-in for local folders. |
